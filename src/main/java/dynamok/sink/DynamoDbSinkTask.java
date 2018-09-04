/*
 * Copyright 2016 Shikhar Bhushan
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package dynamok.sink;

import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.auth.DefaultAWSCredentialsProviderChain;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.model.*;
import com.fasterxml.jackson.core.JsonParseException;
import com.fasterxml.jackson.databind.JsonMappingException;
import com.newrelic.api.agent.NewRelic;
import com.newrelic.api.agent.Trace;
import dynamok.Version;
import dynamok.commons.Util;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.connect.data.Schema;
import org.apache.kafka.connect.errors.ConnectException;
import org.apache.kafka.connect.errors.DataException;
import org.apache.kafka.connect.errors.RetriableException;
import org.apache.kafka.connect.sink.SinkRecord;
import org.apache.kafka.connect.sink.SinkTask;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.Collection;
import java.util.Map;


public class DynamoDbSinkTask extends SinkTask {

    private enum ValueSource {
        RECORD_KEY {
            @Override
            String topAttributeName(ConnectorConfig config) {
                return config.topKeyAttribute;
            }
        },
        RECORD_VALUE {
            @Override
            String topAttributeName(ConnectorConfig config) {
                return config.topValueAttribute;
            }
        };

        abstract String topAttributeName(ConnectorConfig config);
    }

    private final Logger log = LoggerFactory.getLogger(DynamoDbSinkTask.class);

    private ConnectorConfig config;
    private AmazonDynamoDB client;
    private KafkaProducer<String, String> producer;

    @Override
    public void start(Map<String, String> props) {
        config = new ConnectorConfig(props);
        producer = Util.getKafkaProducer(config.broker);
        if (config.accessKeyId.value().isEmpty() || config.secretKey.value().isEmpty()) {
            client = AmazonDynamoDBClientBuilder
                    .standard()
                    .withCredentials(DefaultAWSCredentialsProviderChain.getInstance())
                    .withRegion(config.region)
                    .build();
            log.debug("AmazonDynamoDBStreamsClient created with DefaultAWSCredentialsProviderChain");
        } else {
            final BasicAWSCredentials awsCreds = new BasicAWSCredentials(config.accessKeyId.value(), config.secretKey.value());
            client = AmazonDynamoDBClientBuilder
                    .standard()
                    .withCredentials(new AWSStaticCredentialsProvider(awsCreds))
                    .withRegion(config.region)
                    .build();
            log.debug("AmazonDynamoDBClient created with AWS credentials from connector configuration");
        }
    }

    @Override
    @Trace(dispatcher = true)
    public void put(Collection<SinkRecord> records) {
        if (records.isEmpty()) return;
        NewRelic.incrementCounter("Custom/DynamoDBConnect-RecordsBatch");

        for (final SinkRecord record : records) {
            ProducerRecord<String, String> producerRecord = new ProducerRecord<>(config.errorKafkaTopic,
                    "" + record.key(), record.value().toString());
            try {
                Map<String, Object> valueMap = Util.jsonToMap(record.value().toString());
                DynamoConnectMetaData dynamoConnectMetaData = null;
                SinkRecord newRecord = new SinkRecord(record.topic(), record.kafkaPartition(), null,
                        record.key(), null, valueMap, record.kafkaOffset());
                PutItemRequest putItemRequest = toPutRequest(newRecord).withTableName(tableName(newRecord));
                if (valueMap.containsKey("__metadata")) {
                    Map<String, Object> metadata = (Map<String, Object>) valueMap.get("__metadata");
                    dynamoConnectMetaData = Util.mapToDynamoConnectMetaData(metadata);
                    putItemRequest = putItemRequest
                            .withConditionExpression(dynamoConnectMetaData.getConditionalExpression())
                            .withExpressionAttributeValues(AttributeValueConverter.toAttributeValueSchemaless(dynamoConnectMetaData.getConditionalValueMap()).getM());
                }
                client.putItem(putItemRequest);
            } catch (JsonParseException | JsonMappingException e) {
                log.error("Exception occurred while converting JSON to Map: {}", record, e);
                log.warn("Sending to error topic...");
                producer.send(producerRecord);
            } catch (ConditionalCheckFailedException e) {
                log.debug("Conditional check failed for record: {}", record, e);
                //This is intentional failure for conditional check
            } catch (IOException e) {
                log.error("Exception occurred in Json Parsing", e);
                producer.send(producerRecord);
            } catch (AmazonDynamoDBException e) {
                log.warn("Error in sending data to DynamoDB in record: {}", record, e);
                if (e.getErrorCode().equalsIgnoreCase("ValidationException")) {
                    producer.send(producerRecord);
                } else throw e;
            }
        }
    }

    private PutItemRequest toPutRequest(SinkRecord record) {
        final PutItemRequest pir = new PutItemRequest();
        if (!config.ignoreRecordValue) {
            insert(ValueSource.RECORD_VALUE, record.valueSchema(), record.value(), pir);
        }
        if (!config.ignoreRecordKey) {
            insert(ValueSource.RECORD_KEY, record.keySchema(), record.key(), pir);
        }
        if (config.kafkaCoordinateNames != null) {
            pir.addItemEntry(config.kafkaCoordinateNames.topic, new AttributeValue().withS(record.topic()));
            pir.addItemEntry(config.kafkaCoordinateNames.partition, new AttributeValue().withN(String.valueOf(record.kafkaPartition())));
            pir.addItemEntry(config.kafkaCoordinateNames.offset, new AttributeValue().withN(String.valueOf(record.kafkaOffset())));
        }
        return pir;
    }

    private void insert(ValueSource valueSource, Schema schema, Object value, PutItemRequest pir) {
        final AttributeValue attributeValue;
        try {
            attributeValue = schema == null
                    ? AttributeValueConverter.toAttributeValueSchemaless(value)
                    : AttributeValueConverter.toAttributeValue(schema, value);
        } catch (DataException e) {
            log.error("Failed to convert record with schema={} value={}", schema, value, e);
            throw e;
        }

        final String topAttributeName = valueSource.topAttributeName(config);
        if (!topAttributeName.isEmpty()) {
            pir.addItemEntry(topAttributeName, attributeValue);
        } else if (attributeValue.getM() != null) {
            pir.setItem(attributeValue.getM());
        } else {
            throw new ConnectException("No top attribute name configured for " + valueSource + ", and it could not be converted to Map: " + attributeValue);
        }
    }

    private String tableName(SinkRecord record) {
        return config.tableFormat.replace("${topic}", record.topic());
    }

    @Override
    public void flush(Map<TopicPartition, OffsetAndMetadata> offsets) {
    }

    @Override
    public void stop() {
        if (client != null) {
            client.shutdown();
            client = null;
        }
    }

    @Override
    public String version() {
        return Version.get();
    }

}

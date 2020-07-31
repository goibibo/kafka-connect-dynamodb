FROM alpine:3.9.6

MAINTAINER data-team

ENV JAVA_VERSION 8
ENV JAVA_UPDATE 201
ENV JAVA_BUILD 09
ENV JAVA_SIG 42970487e3af4f5aa5bca3f542482c60
ENV AWS_CLI_VERSION 1.15.4
ENV SCALA_VERSION 2.11
ENV KAFKA_VERSION 0.10.1.0

WORKDIR /opt
RUN apk update && apk add --no-cache bash wget tar curl procps openjdk8 netstat telnet git glibc.i686 unzip gettext && \
        wget https://archive.apache.org/dist/kafka/0.11.0.2/kafka_2.11-0.11.0.2.tgz && \
        tar -xzf kafka_2.11-0.11.0.2.tgz -C /opt/kafka/ && \
        rm -rf /etc/localtime && \
        ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
        

ENV JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk
ENV KAFKA_HOME /opt/kafka/kafka_2.11-0.11.0.2
ENV PATH $PATH:$JAVA_HOME/bin $PATH:$KAFKA_HOME/bin



WORKDIR /opt
RUN yum install -y wget netstat telnet tar git glibc.i686 unzip gettext && \
    wget --no-cookies --header "Cookie:oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/"${JAVA_VERSION}"u"${JAVA_UPDATE}"-b"${JAVA_BUILD}"/"${JAVA_SIG}"/jdk-"${JAVA_VERSION}"u"${JAVA_UPDATE}"-linux-x64.tar.gz && \
    tar -xf jdk-${JAVA_VERSION}u${JAVA_UPDATE}-linux-x64.tar.gz && \
    wget https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    tar -xf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    rm -rf /etc/localtime && \
    ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime

ENV JAVA_HOME /opt/jdk1.${JAVA_VERSION}.0_${JAVA_UPDATE}
ENV KAFKA_HOME /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION}
ENV PATH $PATH:$JAVA_HOME/bin $PATH:$KAFKA_HOME/bin

RUN mkdir /logs/
WORKDIR /usr/local/goibibo/source/kafka-connect-dynamodb

RUN wget -N https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip && \
        unzip newrelic-java.zip

ADD ./newrelic/* ./newrelic/
ADD ./connect-properties ./connect-properties/
ADD ./distribution ./distribution/
ADD ./entrypoint.sh ./
RUN chown root.root ./entrypoint.sh
RUN chmod 700 ./entrypoint.sh

ENV CLASSPATH=./distribution/*
ENV KAFKA_OPTS=-javaagent:./newrelic/newrelic.jar

ENTRYPOINT ["./entrypoint.sh"]

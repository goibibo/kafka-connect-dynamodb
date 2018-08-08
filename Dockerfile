FROM centos:latest

MAINTAINER data-team

ENV JAVA_VERSION 8
ENV JAVA_UPDATE 181
ENV JAVA_BUILD 13
ENV JAVA_SIG 96a7b8442fe848ef90c96a2fad6ed6d1
ENV SCALA_VERSION 2.11
ENV KAFKA_VERSION 0.10.1.0

WORKDIR /opt
RUN yum install -y wget netstat telnet tar git glibc.i686 unzip gettext && \
    wget --no-cookies --header "Cookie:oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/"${JAVA_VERSION}"u"${JAVA_UPDATE}"-b"${JAVA_BUILD}"/"${JAVA_SIG}"/jdk-"${JAVA_VERSION}"u"${JAVA_UPDATE}"-linux-x64.tar.gz && \
    tar -xf jdk-${JAVA_VERSION}u${JAVA_UPDATE}-linux-x64.tar.gz && \
    wget https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    tar -xf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

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
FROM confluentinc/cp-flink:2.2.0-cp2-java21

USER root
COPY perf-sql-executor-0.1.0.jar /opt/flink/usrlib/perf-sql-executor-0.1.0.jar
RUN chown flink:flink /opt/flink/usrlib/perf-sql-executor-0.1.0.jar
USER flink

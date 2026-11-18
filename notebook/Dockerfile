FROM ghcr.io/astral-sh/uv:0.11.8@sha256:3b7b60a81d3c57ef471703e5c83fd4aaa33abcd403596fb22ab07db85ae91347 AS uv

FROM spark:4.3.0-python3@sha256:3f34ea24b3aa6de84c942d463657d203d08455d24e62f2df3ff16d7367bff200

COPY --from=uv /uv /usr/local/bin/uv

USER root

# Jars are baked in so notebooks need no network: spark.jars.packages would resolve them through Ivy at runtime.
# Kafka source plus the runtime deps that /opt/spark/jars lacks, per spark-sql-kafka-0-10_2.13:4.3.0's POM.
ARG MAVEN=https://repo1.maven.org/maven2
ADD --chown=spark:spark --chmod=644 --checksum=sha256:3e458fbf575e8bcdb58f2f3b1a6c51b60e47a75c627f242bc6911fb04de6939b \
    ${MAVEN}/org/apache/spark/spark-sql-kafka-0-10_2.13/4.3.0/spark-sql-kafka-0-10_2.13-4.3.0.jar /opt/spark/jars/
ADD --chown=spark:spark --chmod=644 --checksum=sha256:e36eeca0a3950518567fa8d744e9948880fdc79a478baadad00e305d145d97c9 \
    ${MAVEN}/org/apache/spark/spark-token-provider-kafka-0-10_2.13/4.3.0/spark-token-provider-kafka-0-10_2.13-4.3.0.jar /opt/spark/jars/
ADD --chown=spark:spark --chmod=644 --checksum=sha256:014b4ef36884478a932641818b080c36a8f8e2e92dc771e800c9d2694f4f83d8 \
    ${MAVEN}/org/apache/kafka/kafka-clients/3.9.2/kafka-clients-3.9.2.jar /opt/spark/jars/
ADD --chown=spark:spark --chmod=644 --checksum=sha256:f77a5060d6936a9144023584232f9de3f2248f1abfe156e9d31795f18770674f \
    ${MAVEN}/org/apache/commons/commons-pool2/2.13.1/commons-pool2-2.13.1.jar /opt/spark/jars/
# Iceberg publishes no Spark 4.3 runtime yet; the 4.1 build is the newest release.
ADD --chown=spark:spark --chmod=644 --checksum=sha256:3123c3798af642dd537230923548e013ef41cc28b6626e5225808cf5670a0f82 \
    ${MAVEN}/org/apache/iceberg/iceberg-spark-runtime-4.1_2.13/1.12.0/iceberg-spark-runtime-4.1_2.13-1.12.0.jar /opt/spark/jars/

# Build the venv on the image's own Python; --frozen fails if uv.lock is out of date with pyproject.toml.
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_PYTHON=/usr/bin/python3 \
    UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy \
    UV_NO_CACHE=1
COPY pyproject.toml uv.lock /tmp/notebook/
RUN cd /tmp/notebook \
 && uv sync --frozen --no-install-project \
 && rm -rf /tmp/notebook \
 && mkdir -p /home/spark /workspace \
 && chown spark:spark /home/spark /workspace \
 && chown -R spark:spark /opt/venv
COPY log4j2.properties spark-defaults.conf /opt/spark/conf/

USER spark
# The image ships PySpark under SPARK_HOME rather than as an installed package, and gives the spark user no home directory.
ENV HOME=/home/spark \
    PATH=/opt/venv/bin:$PATH \
    PYTHONPATH=/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.9-src.zip
WORKDIR /workspace

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--ServerApp.root_dir=/workspace", "--IdentityProvider.token="]

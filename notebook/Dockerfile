FROM ghcr.io/astral-sh/uv:0.13.10@sha256:a3ea1357342c1a4bf9a0c53a3deb1b55379aefa037338d8113d5771efa01774f AS uv

FROM spark:4.1.3-python3@sha256:23b155b98033eae36e503b11f613e2091caf30722a599521965925dc2756460a

COPY --from=uv /uv /usr/local/bin/uv

USER root

# Jars are baked in so notebooks need no network: spark.jars.packages would resolve them through Ivy at runtime.
# Kafka source plus the runtime deps that /opt/spark/jars lacks, per spark-sql-kafka-0-10_2.13:4.1.3's POM.
ADD --chown=spark:spark --chmod=644 --checksum=sha256:cb31ffd9c8f5527dba061db8af671d295562092e4f3f5ff42fc249fab8a8fde6 \
    https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.13/4.1.3/spark-sql-kafka-0-10_2.13-4.1.3.jar /opt/spark/jars/
ADD --chown=spark:spark --chmod=644 --checksum=sha256:0535a111d7d11b2859c0a0548d5c8d172c6925f9b8d041d0f0dd38ddc5a3497c \
    https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.13/4.1.3/spark-token-provider-kafka-0-10_2.13-4.1.3.jar /opt/spark/jars/
ADD --chown=spark:spark --chmod=644 --checksum=sha256:7568b998572d256f0b7bc0afdc1b7a2588b8b08415c62ce314c864a6851ae9d9 \
    https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.9.1/kafka-clients-3.9.1.jar /opt/spark/jars/
ADD --chown=spark:spark --chmod=644 --checksum=sha256:5273c8bc8c0dca2211175c0d27efbd7228efae99689aac001a8e1ef8e872e9ef \
    https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.12.1/commons-pool2-2.12.1.jar /opt/spark/jars/
# Iceberg runtimes are tied to a Spark minor version, and 4.1 is the newest one Iceberg has released for.
ADD --chown=spark:spark --chmod=644 --checksum=sha256:3123c3798af642dd537230923548e013ef41cc28b6626e5225808cf5670a0f82 \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.1_2.13/1.12.0/iceberg-spark-runtime-4.1_2.13-1.12.0.jar /opt/spark/jars/

# Build the venv on the image's own Python; --frozen fails if uv.lock is out of date with pyproject.toml.
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_PYTHON=/usr/bin/python3 \
    UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy \
    UV_NO_CACHE=1
COPY pyproject.toml uv.lock /tmp/notebook/
RUN uv sync --project /tmp/notebook --frozen --no-install-project \
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

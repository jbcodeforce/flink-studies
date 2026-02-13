# Flink Agent Demos

Based [on Flink Agents docs](https://nightlies.apache.org/flink/flink-agents-docs-release-0.1/)

## Installation

* Use Apache Flink install script
    ```sh
    # in deployment/product-tar
    ./install-flink-local.sh 1.20.3
    ```

* Activate the venv for Python 3.11
    ```sh
    uv venv -p 3.11
    source .venv/bin/activate
    uv run python --version 
    ```

* Add flink-agents module
    ```sh
    uv add flink-agents
    ```

* As Flink runs in its own JVM process and needs the PYTHONPATH environment variable to locate the flink-agents Python package.
    ```sh
    export PYTHONPATH=$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')
    ```


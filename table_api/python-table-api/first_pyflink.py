from pyflink.table import EnvironmentSettings, TableEnvironment

   # Set the environment settings for Flink
env_settings = EnvironmentSettings.in_streaming_mode()


t_env = TableEnvironment.create(
    env_settings
)

# Define your Table API logic here
t_env.execute_sql("CREATE TABLE my_table (id INT, name STRING) WITH ('connector' = 'filesystem', 'path' = '/data)")
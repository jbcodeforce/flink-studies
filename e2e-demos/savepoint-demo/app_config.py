import yaml

def read_config():
  # reads the client configuration from client.properties
  # and returns it as a key-value map
  configuration = None
  with open("config.yaml") as f:
    configuration=yaml.load(f,Loader=yaml.FullLoader)
  return configuration

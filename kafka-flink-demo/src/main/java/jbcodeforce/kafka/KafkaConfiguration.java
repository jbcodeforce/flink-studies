package jbcodeforce.kafka;

import java.util.Optional;
import java.util.Properties;

import org.apache.kafka.clients.CommonClientConfigs;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.config.SaslConfigs;
import org.apache.kafka.common.config.SslConfigs;
import org.eclipse.microprofile.config.ConfigProvider;
import org.jboss.logging.Logger;

/**
 * Centralize in one class the Kafka Configuration. Useful when app has producer
 * and consumer
 */
public class KafkaConfiguration {
    protected static final Logger logger = Logger.getLogger(KafkaConfiguration.class.getName());

    public  String mainTopicName = "telemetries";
    public  String truststoreLocation = "";
    public  String truststorePassword = "";
    public  String bootstrapServers = null; 

    public KafkaConfiguration(){}

    public KafkaConfiguration(String bootStrap) {
        this.bootstrapServers = bootStrap;
    }
    /**
     * @return common kafka properties
     */
    private  Properties buildCommonProperties() {
        Properties properties = new Properties();

        Optional<String> topic = ConfigProvider.getConfig().getOptionalValue("kafka.topic.name", String.class);
        if (topic.isPresent()) {
            mainTopicName = topic.get();
        }

        if (bootstrapServers == null) {
            bootstrapServers = ConfigProvider.getConfig().getValue("kafka.bootstrap.servers", String.class);
        }

        properties.put(CommonClientConfigs.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        
        
        Optional<String> v = ConfigProvider.getConfig().getOptionalValue("kafka.security.protocol", String.class);
        if (v.isPresent()) {
            properties.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, v.get());
        }
        v = ConfigProvider.getConfig().getOptionalValue("kafka.sasl.mechanism", String.class);
        if (v.isPresent()) {
            properties.put(SaslConfigs.SASL_MECHANISM, v.get());
        }
      
        v = ConfigProvider.getConfig().getOptionalValue("kafka.sasl.jaas.config", String.class);
        if (v.isPresent()) {
            properties.put(SaslConfigs.SASL_JAAS_CONFIG, v.get());
        }
        properties.put(SslConfigs.SSL_PROTOCOL_CONFIG, "TLSv1.2");
        properties.put(SslConfigs.SSL_ENABLED_PROTOCOLS_CONFIG, "TLSv1.2");
        properties.put(SslConfigs.SSL_ENDPOINT_IDENTIFICATION_ALGORITHM_CONFIG, "HTTPS");
        
        v = ConfigProvider.getConfig().getOptionalValue("kafka.ssl.truststore.location", String.class);
        if (v.isPresent()) {
            properties.put(SslConfigs.SSL_TRUSTSTORE_LOCATION_CONFIG, v.get());
            truststoreLocation = v.get();
        }

        v = ConfigProvider.getConfig().getOptionalValue("kafka.ssl.truststore.password", String.class);
        if (v.isPresent()) {
            properties.put(SslConfigs.SSL_TRUSTSTORE_PASSWORD_CONFIG, v.get());
            truststorePassword = v.get();
        }

        v = ConfigProvider.getConfig().getOptionalValue("kafka.ssl.keystore.location", String.class);
        if (v.isPresent()) {
            properties.put(SslConfigs.SSL_KEYSTORE_LOCATION_CONFIG, v.get());
        }

        v = ConfigProvider.getConfig().getOptionalValue("kafka.ssl.keystore.password", String.class);
        if (v.isPresent()) {
            properties.put(SslConfigs.SSL_KEYSTORE_PASSWORD_CONFIG, v.get());
        }
      
        return properties;
    }



    public Properties getConsumerProperties(String groupId) {
        Properties properties = buildCommonProperties();
        properties.put(ConsumerConfig.GROUP_ID_CONFIG,groupId);
        Optional<String> vs = ConfigProvider.getConfig().getOptionalValue("kafka.value.deserializer", String.class);
        if (vs.isPresent()) {
            properties.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, vs.get());
        } else {
            properties.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
        }

        vs = ConfigProvider.getConfig().getOptionalValue("kafka.key.deserializer", String.class);
        if (vs.isPresent()) {
            properties.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, vs.get());
        } else {
            properties.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
        }
        return properties;
    }

    public  Properties getProducerProperties(String clientID) {
        Properties properties = buildCommonProperties();
        
        Optional<Long> v = ConfigProvider.getConfig().getOptionalValue("kafka.producer.timeout.sec", Long.class);
        if (v.isPresent()) {
            properties.put(ProducerConfig.DELIVERY_TIMEOUT_MS_CONFIG, v.get());
        }

        Optional<String> vs = ConfigProvider.getConfig().getOptionalValue("kafka.producer.acks", String.class);
        if (vs.isPresent()) {
            properties.put(ProducerConfig.ACKS_CONFIG, vs.get());
        } else {
            properties.put(ProducerConfig.ACKS_CONFIG, "all");
        }
    
        Optional<Boolean> vb = ConfigProvider.getConfig().getOptionalValue("kafka.producer.idempotence", Boolean.class);
        if (vb.isPresent()) {
            properties.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, vb.get());
        } else {
            properties.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, false);
        }
    
        Optional<Integer> vi = ConfigProvider.getConfig().getOptionalValue("kafka.producer.retries", Integer.class);
        if (vi.isPresent()) {
            properties.put(ProducerConfig.RETRIES_CONFIG, vi.get());
        } else {
            properties.put(ProducerConfig.RETRIES_CONFIG, 0);
        }
     
        vs = ConfigProvider.getConfig().getOptionalValue("kafka.key.serializer", String.class);
        if (vs.isPresent()) {
            properties.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, vs.get());
        } else {
            properties.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
        }

        vs = ConfigProvider.getConfig().getOptionalValue("kafka.value.serializer", String.class);
        if (vs.isPresent()) {
            properties.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, vs.get());
        } else {
            properties.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
        }
        
        properties.put(ProducerConfig.CLIENT_ID_CONFIG, clientID);
       
        properties.forEach((k, val) -> logger.info(k + " : " + val));
        return properties;
    }

    public  String getTopicName(){
        return mainTopicName;
    }
}

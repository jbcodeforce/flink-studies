package jbcodeforce.kafka;
import java.io.IOException;

import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.ObjectMapper;

public class TelemetryDeserializationSchema implements DeserializationSchema<TelemetryEvent> {

    private static final long serialVersionUID = -3142470930494715773L;
    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Override
	public TelemetryEvent deserialize(byte[] message) throws IOException {
		return objectMapper.readValue(message, TelemetryEvent.class);
	}

	@Override
	public boolean isEndOfStream(TelemetryEvent nextElement) {
		return false;
	}

	@Override
	public TypeInformation<TelemetryEvent> getProducedType() {
		return TypeInformation.of(TelemetryEvent.class);
	}
    
}
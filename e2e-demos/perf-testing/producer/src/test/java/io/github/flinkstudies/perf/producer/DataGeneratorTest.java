package io.github.flinkstudies.perf.producer;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

class DataGeneratorTest {

    @Test
    void buildRecord_respectsTargetSize() {
        String json = DataGenerator.buildRecord(42L, 256);
        assertTrue(json.getBytes().length >= 200, "payload should be near target size");
        assertTrue(json.contains("\"id\":42"));
        assertTrue(json.contains("\"event_time\""));
        assertTrue(json.contains("\"payload\""));
    }

    @Test
    void buildRecord_isValidJsonShape() {
        String json = DataGenerator.buildRecord(1L, 128);
        assertTrue(json.startsWith("{"));
        assertTrue(json.endsWith("}"));
    }
}

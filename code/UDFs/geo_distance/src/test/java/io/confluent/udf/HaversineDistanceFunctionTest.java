package io.confluent.udf;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class HaversineDistanceFunctionTest {
    private GeoDistanceFunction geoDistance;

    @BeforeEach
    void setUp() {
        geoDistance = new GeoDistanceFunction();
    }

    @Test
    void testKnownDistance() {
        // Test with known coordinates and distance
        // Paris (48.8566° N, 2.3522° E) to London (51.5074° N, 0.1278° W)
        double distance = geoDistance.eval(48.8566, 2.3522, 51.5074, -0.1278);
        assertEquals(343.5, distance, 1.0); // Allow 1km tolerance
    }

    @Test
    void testSamePoint() {
        // Distance to same point should be 0
        double distance = geoDistance.eval(40.7128, -74.0060, 40.7128, -74.0060);
        assertEquals(0.0, distance, 0.0001);
    }

    @Test
    void testAntipodalPoints() {
        // Test with antipodal points (opposite sides of Earth)
        double distance = geoDistance.eval(0.0, 0.0, 0.0, 180.0);
        assertEquals(20015.0, distance, 10.0); // Approximately half Earth's circumference
    }

    @Test
    void testToString() {
        assertEquals("GEO_DISTANCE", geoDistance.toString());
    }
}

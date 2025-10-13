package io.confluent.udf;

import org.apache.flink.table.functions.ScalarFunction;

/**
 * A Flink UDF that calculates the Haversine distance between two points on Earth.
 * The Haversine formula determines the great-circle distance between two points on a sphere
 * given their latitudes and longitudes.
 */
public class GeoDistanceFunction extends ScalarFunction {
    private static final double EARTH_RADIUS_KM = 6371.0; // Earth's radius in kilometers

    /**
     * Calculates the distance between two points on Earth using the Haversine formula.
     *
     * @param lat1 Latitude of the first point in degrees
     * @param lon1 Longitude of the first point in degrees
     * @param lat2 Latitude of the second point in degrees
     * @param lon2 Longitude of the second point in degrees
     * @return The distance between the points in kilometers
     */
    public double eval(double lat1, double lon1, double lat2, double lon2) {
        // Convert latitude and longitude from degrees to radians
        double lat1Rad = Math.toRadians(lat1);
        double lon1Rad = Math.toRadians(lon1);
        double lat2Rad = Math.toRadians(lat2);
        double lon2Rad = Math.toRadians(lon2);

        // Differences in coordinates
        double dLat = lat2Rad - lat1Rad;
        double dLon = lon2Rad - lon1Rad;

        // Haversine formula
        double a = Math.pow(Math.sin(dLat / 2), 2) +
                   Math.cos(lat1Rad) * Math.cos(lat2Rad) *
                   Math.pow(Math.sin(dLon / 2), 2);
        
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        // Calculate the distance
        return EARTH_RADIUS_KM * c;
    }

    /**
     * Returns a string describing the function.
     */
    @Override
    public String toString() {
        return "GEO_DISTANCE";
    }
}

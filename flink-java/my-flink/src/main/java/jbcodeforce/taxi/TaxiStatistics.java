package jbcodeforce.taxi;

import org.apache.flink.api.common.functions.FilterFunction;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.functions.ReduceFunction;
import org.apache.flink.api.java.DataSet;
import org.apache.flink.api.java.ExecutionEnvironment;
import org.apache.flink.api.java.functions.KeySelector;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.tuple.Tuple3;
import org.apache.flink.api.java.tuple.Tuple4;
import org.apache.flink.api.java.tuple.Tuple5;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.core.fs.FileSystem.WriteMode;

/**
 * Compute the most popular destination Taxi ride from file cab_rides.txt in the
 * form: 0 , 1 , 2 , 3 , 4 , 5 , 6 , 7 
 * # cab id, cab number plate, cab type, cab driver name, ongoing trip/not, pickup location, destination, passenger count
 * 
 * The Average passenger per trip: place to pickup most passenger
 * 
 * The average passenger per driver
 */
public class TaxiStatistics {
    public static void main(String[] args) throws Exception {
        ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();
        ParameterTool params = ParameterTool.fromArgs(args);
        env.getConfig().setGlobalJobParameters(params);

        // remove records with no ongoing trip, and keep important attributes:
        // cab driver name, pickup location, destination, passenger count
        DataSet<Tuple5<String, String, String, Boolean, Integer>> taxiRides = env.readTextFile(params.get("input"))
                .map(new MapTrip()).filter(new GetValidDestinations());
        taxiRides.writeAsText("/home/my-flink/data/filteredTaxis.txt", WriteMode.OVERWRITE);

        mostPopularDestination(taxiRides).writeAsText("/home/my-flink/data/popularDestinations.txt",
                WriteMode.OVERWRITE);

        computeAverageNumberOfPassengerAtPickupPlace(taxiRides).writeAsText("/home/my-flink/data/averagePickup.txt",
                WriteMode.OVERWRITE);

        computeAveragePassengerPerDriver(taxiRides).writeAsText("/home/my-flink/data/averagePerDriver.txt",
        WriteMode.OVERWRITE);
        env.execute("Taxi Rides Statistics");
    }

    /**
     * key on destination sum on the count and max it. attributes are 
     * 0: cab driver name, 1: pickup location, 2: destination, 3: passenger count
     */
    public static DataSet<Tuple5<String, String, String, Boolean, Integer>> mostPopularDestination(
            DataSet<Tuple5<String, String, String, Boolean, Integer>> taxiRides) {
        return taxiRides.groupBy(2).sum(4).maxBy(4);
    }

    public static class MapTrip implements MapFunction<String, Tuple5<String, String, String, Boolean, Integer>> {

        @Override
        public Tuple5<String, String, String, Boolean, Integer> map(String value) throws Exception {
            String[] attributes = value.split(",");
            if (attributes[4].equalsIgnoreCase("yes")) {
                return new Tuple5<String, String, String, Boolean, Integer>(attributes[3], attributes[5], attributes[6],
                        true, Integer.parseInt(attributes[7]));
            } else {
                return new Tuple5<String, String, String, Boolean, Integer>(attributes[3], attributes[5], attributes[6],
                        false, 0);
            }
        }

    }

    public static class MapPassengerCount implements
            MapFunction<Tuple5<String, String, String, Boolean, Integer>, Tuple4<String, String, Integer, Integer>> {

        @Override
        public Tuple4<String, String, Integer, Integer> map(Tuple5<String, String, String, Boolean, Integer> valueIn)
                throws Exception {
            return new Tuple4<String, String, Integer, Integer>(valueIn.f0, valueIn.f1, valueIn.f4, 1);
        }
    }

    /**
     * Retains elements for which the function returns true
     */
    public static class GetValidDestinations
            implements FilterFunction<Tuple5<String, String, String, Boolean, Integer>> {
        @Override
        public boolean filter(Tuple5<String, String, String, Boolean, Integer> value) throws Exception {

            return value.f3;
        }

    }

    public static class AccumulatePassengerCount implements ReduceFunction<Tuple2<String, Integer>> {

        @Override
        public Tuple2<String, Integer> reduce(Tuple2<String, Integer> current, Tuple2<String, Integer> previous)
                throws Exception {

            return new Tuple2<String, Integer>(current.f0, current.f1 + previous.f1);
        }

    }

   
    public static DataSet<Tuple2<String, Double>> computeAveragePassengerPerDriver(
            DataSet<Tuple5<String, String, String, Boolean, Integer>> data) {
        return data.map(new MapPassengerCount()).groupBy(0) // key is driver location
                .reduce(new ReduceFunction<Tuple4<String, String, Integer, Integer>>() {
                    public Tuple4<String, String, Integer, Integer> reduce(Tuple4<String, String,  Integer, Integer> v1,
                    Tuple4<String, String, Integer, Integer> v2) {
                        return new Tuple4<String, String, Integer, Integer>(v1.f0, v1.f1, v1.f2 + v2.f2, v1.f3 + v2.f3);
                    }
                }).map(new MapFunction<Tuple4<String, String, Integer, Integer>, Tuple2<String, Double>>() {
                    public Tuple2<String, Double> map(Tuple4<String, String, Integer, Integer> value) {
                        return new Tuple2<String, Double>(value.f0, ((value.f2 * 1.0) / value.f3));
                    }
                });
    }

     /**
     * Compute average # of passengers per trip source. This represents place to
     * pickup most passengers
     */
    public static DataSet<Tuple2<String, Double>> computeAverageNumberOfPassengerAtPickupPlace(
            DataSet<Tuple5<String, String, String, Boolean, Integer>> data) {
        return data.map(new MapPassengerCount()).groupBy(1) // key is pickup location
                .reduce(new ReduceFunction<Tuple4<String, String, Integer, Integer>>() {
                    public Tuple4<String, String, Integer, Integer> reduce(Tuple4<String, String,  Integer, Integer> v1,
                    Tuple4<String, String, Integer, Integer> v2) {
                        return new Tuple4<String, String, Integer, Integer>(v1.f0, v1.f1, v1.f2 + v2.f2, v1.f3 + v2.f3);
                    }
                }).map(new MapFunction<Tuple4<String, String, Integer, Integer>, Tuple2<String, Double>>() {
                    public Tuple2<String, Double> map(Tuple4<String, String, Integer, Integer> value) {
                        return new Tuple2<String, Double>(value.f1, ((value.f2 * 1.0) / value.f3));
                    }
                });
    }

    public static class GetDestinationAsKey implements KeySelector<Tuple4<String, String, String, Integer>, String> {
        /**
         *
         */
        private static final long serialVersionUID = 2059704033291863808L;

        @Override
        public String getKey(Tuple4<String, String, String, Integer> value) throws Exception {
            return value.f2;
        }

    }
}

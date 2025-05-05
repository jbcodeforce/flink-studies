package jbcodeforce.windows;

import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.functions.ReduceFunction;
import org.apache.flink.api.java.functions.KeySelector;
import org.apache.flink.api.java.tuple.Tuple5;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.core.fs.FileSystem.WriteMode;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.assigners.SlidingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;

public class TumblingWindowOnSale {
    public static void main(String[] args) throws Exception {
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        // Specify time to use
        env.getConfig().setAutoWatermarkInterval(2);
		
        final ParameterTool params = ParameterTool.fromArgs(args);
        env.getConfig().setGlobalJobParameters(params);

        // record ex: 01-06-2018,June,Category5,Bat,12
        DataStream<String> saleStream = env.socketTextStream("host.docker.internal", 9181);
        // Map to new tuple: month, product, category, profit, count
        DataStream<Tuple5<String, String, String, Integer, Integer>> mappedSale = saleStream.map(new Splitter());

        DataStream<Tuple5<String, String, String, Integer, Integer>>  reduced = mappedSale
            .keyBy(new GetMonthAsKey())
            .window(TumblingProcessingTimeWindows.of(Time.seconds(2)))
            //.window(SlidingProcessingTimeWindows.of(Time.seconds(2), Time.seconds(1)))
            .reduce(new AccumulateProfitAndRecordCount());   
        reduced.writeAsText("/home/my-flink/data/profitPerMonthWindowed.txt",WriteMode.OVERWRITE);
		// execute program
		env.execute("Avg Profit Per Month");
    }

    /**
     * From tuple: date, month, product, category, profit
     * Return a tuple: month, product, category, profit, count
     */
    public static class Splitter implements MapFunction<String, Tuple5<String, String, String, Integer, Integer>> {

        private static final long serialVersionUID = 2583421585155427912L;
        @Override
        public Tuple5<String, String, String, Integer, Integer> map(String value) throws Exception {
            String[] attributes = value.split(",");
            return new Tuple5<String, String, String, Integer, Integer>(attributes[1], attributes[3], attributes[2],
                    Integer.parseInt(attributes[4]), 1);
        }
    } // splitter

    public static class GetMonthAsKey implements KeySelector<Tuple5<String, String, String, Integer, Integer>,String> {
        /**
         *
         */
        private static final long serialVersionUID = 2059704033291863808L;

        @Override
        public String getKey(Tuple5<String, String, String, Integer, Integer> value) throws Exception {
            return value.f0;
        }
        
    }

    public static class AccumulateProfitAndRecordCount implements ReduceFunction<Tuple5<String, String, String, Integer, Integer>> {

        private static final long serialVersionUID = 1L;
        @Override
        public Tuple5<String, String, String, Integer, Integer> reduce(
                Tuple5<String, String, String, Integer, Integer> current,
                Tuple5<String, String, String, Integer, Integer> previous) throws Exception {
           
            return new Tuple5<String, String, String, Integer, Integer>(current.f0,current.f1,current.f2,current.f3 + previous.f3, current.f4 + previous.f4);
        }
    }

}

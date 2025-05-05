package jbcodeforce.datastream;

import java.io.File;

import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.functions.ReduceFunction;
import org.apache.flink.api.java.functions.KeySelector;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.tuple.Tuple5;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.datastream.DataStreamUtils;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.filesystem.StreamingFileSink;

public class ProfitAverageMR {
    public static void main(String[] args) throws Exception {
        // set up the stream execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        final ParameterTool params = ParameterTool.fromArgs(args);
        env.getConfig().setGlobalJobParameters(params);

        DataStream<String> saleStream = env.readTextFile(params.get("input"));
        // month, product, category, profit, count
        DataStream<Tuple5<String, String, String, Integer, Integer>> mappedSale = saleStream.map(new Splitter());
        // groupBy 'month'                                                                                           
        DataStream<Tuple5<String, String, String, Integer, Integer>> reduced = mappedSale.keyBy(new GetMonthAsKey()).reduce(new AccumulateProfitAndRecordCount()); 
        DataStream<Tuple2<String, Double>> profitPerMonth = reduced.map(new MapFunction<Tuple5<String, String, String, Integer, Integer>, Tuple2<String, Double>>()
			{
				public Tuple2<String, Double> map(Tuple5<String, String, String, Integer, Integer> input)
					{
						return new Tuple2<String, Double>(input.f0, Double.valueOf((input.f3*1.0)/input.f4));
					}
                });
        if (params.has("bucket")) {
            //final File folder = new File(params.get("bucket"));
            profitPerMonth.print(); 
           // profitPerMonth.addSink(StreamingFileSink.forRowFormat(
            //    Path.fromLocalFile(folder),).build();
        } else {
            profitPerMonth.writeAsText("/home/my-flink/data/profitPerMonth.txt");  
        }
        env.execute("Average profit per month");
    }

    /**
     * Value is a string like: 01-06-2018,June,Category5,Bat,12 Ouput is a tuple:
     * month, product, category, profit, count
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

    /**
     * Reduce current tuple with previous one by adding profit and count.
     * Record structure is month, product, category, profit, count
     */
    public static class AccumulateProfitAndRecordCount implements ReduceFunction<Tuple5<String, String, String, Integer, Integer>> {

        private static final long serialVersionUID = 1L;
        @Override
        public Tuple5<String, String, String, Integer, Integer> reduce(
                Tuple5<String, String, String, Integer, Integer> current,
                Tuple5<String, String, String, Integer, Integer> previous) throws Exception {
           
            return new Tuple5<String, String, String, Integer, Integer>(current.f0,current.f1,current.f2,current.f3 + previous.f3, current.f4 + previous.f4);
        }
    }

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
}

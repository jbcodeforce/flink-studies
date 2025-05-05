package jbcodeforce.datastream;

import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.tuple.Tuple4;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

public class ComputeAggregates {
    public static void main(String[] args) throws Exception 
	{
		// set up the streaming execution environment
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

		DataStream<String> data = env.readTextFile("/home/my-flink/data/avg.txt");
		
		// month, category,product, profit, 
		DataStream<Tuple4<String, String, String, Integer>> mapped = data.map(new Splitter());      // tuple  [June,Category5,Bat,12]
		                                                                                            //       [June,Category4,Perfume,10,1]
		mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0 ).sum(3).writeAsText("/home/my-flink/data/out1");

		mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0 ).min(3).writeAsText("/home/my-flink/data/out2");
		
	   	mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0) .minBy(3).writeAsText("/home/my-flink/data/out3");
		
		mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0 ).max(3).writeAsText("/home/my-flink/data/out4");
		
		mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0 ).maxBy(3).writeAsText("/home/my-flink/data/out5");
		// execute program
		env.execute("Aggregation");
	}
                                                                                           
	 // *************************************************************************
    // USER FUNCTIONS                                                                                      
    // *************************************************************************
		
	public static class Splitter implements MapFunction<String, Tuple4<String, String, String, Integer>> 
	{
		public Tuple4<String, String, String, Integer> map(String value)         // 01-06-2018,June,Category5,Bat,12
		{
			String[] words = value.split(",");                             // words = [{01-06-2018},{June},{Category5},{Bat}.{12}
			// ignore timestamp, we don't need it for any calculations
			return new Tuple4<String, String, String, Integer>(words[1], words[2],	words[3], Integer.parseInt(words[4])); 
		}                                                  //    June    Category5      Bat               12 
	}
}

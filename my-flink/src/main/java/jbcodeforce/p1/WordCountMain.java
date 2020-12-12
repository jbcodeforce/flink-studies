package jbcodeforce.p1;

import org.apache.flink.api.common.functions.FilterFunction;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.DataSet;
import org.apache.flink.api.java.ExecutionEnvironment;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.utils.ParameterTool;

public class WordCountMain {
    
    public static void main(String[] args) throws Exception {
        // get environment context
        ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();
        ParameterTool params = ParameterTool.fromArgs(args);
        env.getConfig().setGlobalJobParameters(params);
        
        // each line in the file will be in its own dataset
        DataSet<String> text = env.readTextFile(params.get("input"));
        DataSet<String> filtered = text.filter(new FilterFunction<String>() {
                public boolean filter(String value) {
                    return value.startsWith("N");
                }
            });
    DataSet<Tuple2<String, Integer>> tokenized = filtered.map(new Tokenizer());
    
    DataSet<Tuple2<String, Integer>> counts = tokenized.groupBy(new int[] { 0 }).sum(1);
    if (params.has("output")) {
      counts.writeAsCsv(params.get("output"), "\n", " ");
      env.execute("WordCount Example");
    }
  }
  
  public static final class Tokenizer implements MapFunction<String, Tuple2<String, Integer>> {
    public Tuple2<String, Integer> map(String value) {
      return new Tuple2(value, Integer.valueOf(1));
    }
    }
}

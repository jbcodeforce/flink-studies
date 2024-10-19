package jbcodeforce.p1;

import org.apache.flink.api.common.functions.JoinFunction;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.DataSet;
import org.apache.flink.api.java.ExecutionEnvironment;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.tuple.Tuple3;
import org.apache.flink.api.java.utils.ParameterTool;

/**
 * Do a left join on person and location.
 * @param args
 * @throws Exception
 */
public class LeftOuterJoin {
    
    public static void main(String[] args) throws Exception {
        // get environment context
        ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();
        ParameterTool params = ParameterTool.fromArgs(args);
        env.getConfig().setGlobalJobParameters(params);

        // Read persons (row format is idx, name)
        DataSet<Tuple2<Integer,String>> personSet = env.readTextFile(params.get("persons"))
                .map(new MapFunction<String, Tuple2<Integer,String>>() {
                        public Tuple2<Integer,String> map(String value) {
                            String[] words = value.split(",");
                            return new Tuple2<Integer,String>(Integer.parseInt(words[0]), words[1]);
                        }
                });
        // read locations
        DataSet<Tuple2<Integer,String>> locationSet = env.readTextFile(params.get("locations"))
        .map(new MapFunction<String, Tuple2<Integer,String>>() {
                public Tuple2<Integer,String> map(String value) {
                    String[] words = value.split(",");
                    return new Tuple2<Integer,String>(Integer.parseInt(words[0]), words[1]);
                }
        });
        // perform the join on the 'personID'
        DataSet<Tuple3<Integer,String,String>> joinedSet = 
            personSet.leftOuterJoin(locationSet)
            .where(0) // indice of the field to be used to do join from first tuple
            .equalTo(0)  // to match the field in idx 0 of the second tuple
            .with( new JoinFunction<Tuple2<Integer, String>, 
                                    Tuple2<Integer, String>, 
                                    Tuple3<Integer, String, String>>() {
                
                public Tuple3<Integer, String, String> join(
                        Tuple2<Integer, String> person,  
                        Tuple2<Integer, String> location)  {
                    if (location == null) {
                        return new Tuple3<Integer, String, String>(person.f0, person.f1, "NULL");
                    }
                    return new Tuple3<Integer, String, String>(person.f0,   person.f1,  location.f1);
                }              
            });
                
        joinedSet.writeAsCsv(params.get("output"), "\n", " ");
        
        env.execute("Join example");
    
    }
}

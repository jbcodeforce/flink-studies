package jbcodeforce.p1;

import org.apache.flink.api.common.functions.JoinFunction;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.DataSet;
import org.apache.flink.api.java.ExecutionEnvironment;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.tuple.Tuple3;
import org.apache.flink.api.java.utils.ParameterTool;

/**
 * Proceed two files and do an inner join
 * Persons is a form of 
 *   1, Albert
 *   2, Jennifer
 * 
 * Locations is 
 *   2, NY
 * Output will be 2, jennifer, NY
 * 
 * Example of running this:
 * 
 * flink run -d -c jbcodeforce.p1.InnerJoin /home/my-flink/target/my-flink-1.0.0-SNAPSHOT.jar --persons file:///home/my-flink/data/persons.txt --locations file:///home/my-flink/data/locations.txt --output file:///home/my-flink/data/joinout.csv
 */
public class InnerJoin {
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
        // read location
        DataSet<Tuple2<Integer,String>> locationSet = env.readTextFile(params.get("locations"))
        .map(new MapFunction<String, Tuple2<Integer,String>>() {
                public Tuple2<Integer,String> map(String value) {
                    String[] words = value.split(",");
                    return new Tuple2<Integer,String>(Integer.parseInt(words[0]), words[1]);
                }
        });
        // perform the join on the 'personID'
        DataSet<Tuple3<Integer,String,String>> joinedSet = 
            personSet.join(locationSet)
            .where(0) // indice of the field to be used to do join from first tuple
            .equalTo(0)  // to match the field in idx 0 of the second tuple
            .with( new JoinFunction<Tuple2<Integer, String>, 
                                    Tuple2<Integer, String>, 
                                    Tuple3<Integer, String, String>>() {
                
                public Tuple3<Integer, String, String> join(Tuple2<Integer, String> person,  Tuple2<Integer, String> location)  {
                    return new Tuple3<Integer, String, String>(person.f0,   person.f1,  location.f1);
                }              
            });
                
        joinedSet.writeAsCsv(params.get("output"), "\n", " ");
        
        env.execute("Join example");
    
    }
}

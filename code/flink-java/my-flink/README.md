# my-flink project

The current codes use deprecated DataSet API. See the table api folder for ported examples.

Build with maven:  `mvn package`

To run each example:

* WordCount of the file data/wc.txt

```sh
java -cp target/my-flink-1.0.0-runner.jar jbcodeforce.p1.WordCountMain--input data/wc.txt --output count
```

* Filter customer with data defined in code

```sh
java -cp target/my-flink-1.0.0-runner.jar jbcodeforce.p1.PersonFiltering 
```

* Left Join

```sh
java -cp target/my-flink-1.0.0-runner.jar jbcodeforce.p1.LeftOuterJoin --persons data/persons.txt --locations data/locations.txt --output tmp 
```
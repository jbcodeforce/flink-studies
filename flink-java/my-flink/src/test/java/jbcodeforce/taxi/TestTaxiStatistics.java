package jbcodeforce.taxi;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.tuple.Tuple5;
import org.junit.jupiter.api.Test;

import jbcodeforce.taxi.TaxiStatistics.AccumulatePassengerCount;
import jbcodeforce.taxi.TaxiStatistics.GetValidDestinations;
import jbcodeforce.taxi.TaxiStatistics.MapTrip;

public class TestTaxiStatistics {
    
    @Test
    public void testMapToTuple() throws Exception {
        MapTrip mapFunction = new MapTrip();
        Tuple5<String,String,String, Boolean, Integer> t = mapFunction.map("id_4214,PB7526,Sedan,Wanda,yes,Sector 19,Sector 10,5");
        assertEquals("Wanda",t.f0);
        assertEquals("Sector 19",t.f1);
        assertEquals("Sector 10",t.f2);
        assertTrue(t.f3);
        assertEquals(5,t.f4);
    }

    @Test
    public void testNotFilteringGoodDestination() throws Exception {
        MapTrip mapFunction = new MapTrip();
        Tuple5<String,String,String, Boolean, Integer> t = mapFunction.map("id_4214,PB7526,Sedan,Wanda,yes,Sector 19,Sector 10,5");

        GetValidDestinations filterFunction = new GetValidDestinations();
        assertTrue(filterFunction.filter(t));
    }

    @Test
    public void testFilteringNoTrip() throws Exception {
        MapTrip mapFunction = new MapTrip();
        Tuple5<String,String,String, Boolean, Integer> t = mapFunction.map("id_4214,PB7526,Sedan,Wanda,no,Sector 19,null,5");

        GetValidDestinations filterFunction = new GetValidDestinations();
        assertFalse(filterFunction.filter(t));
    }

    @Test
    public void testAccumulatePassenger() throws Exception {
        AccumulatePassengerCount reduceOnCount = new AccumulatePassengerCount();
        Tuple2<String,Integer> current = new Tuple2<String,Integer>("destination",10);
        Tuple2<String,Integer> previous = new Tuple2<String,Integer>("destination",3);
        Tuple2<String,Integer> newCount = reduceOnCount.reduce(current, previous);
        assertEquals(13,newCount.f1);
    }
}

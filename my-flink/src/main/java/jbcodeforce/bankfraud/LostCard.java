package jbcodeforce.bankfraud;

/**
 * Reported lost card
 */
public class LostCard {

    public final String id;
    public final String timestamp;
    public final String name;
    public final String status;

    public LostCard(){
	id = "";
	timestamp = "";
	name = "";
	status = "";
    }

    public LostCard(String data){
	String[] words = data.split(",");
	id = words[0];
	timestamp = words[1];
	name = words[2];
	status = words[3];
    }

}

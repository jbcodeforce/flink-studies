package jbcodeforce.bankfraud;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;

/**
 * Send card transaction to a socket to build a data stream.
 * Input is from a file
 */
public class BankDataServer {
    public static void main(String[] args) throws IOException{
	ServerSocket listener = new ServerSocket(9090);
	BufferedReader br = null;
	try{
	    Socket socket = listener.accept();
	    System.out.println("Got new connection: " + socket.toString());

	    br = new BufferedReader(new FileReader("./data/bank/bank_data.txt"));
	    
	    try {		
		PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
		String line;

		while((line = br.readLine()) != null){
		    out.println(line);
		    Thread.sleep(500);
		}
					
	    } finally{
		socket.close();
	    }
			
	} catch(Exception e ){
	    e.printStackTrace();
	} finally{	    
	    listener.close();
	    if (br != null)
		br.close();
	}
    }
}


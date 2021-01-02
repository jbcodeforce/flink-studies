package jbcodeforce.sale;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;

public class SaleDataServer {
    public static final boolean AUTO_FLUSH = true;
    public static final int PORT = 9181;
    public static void main(String[] args) {
        try {
            System.out.println("Listen on port " + PORT);
            ServerSocket listener = new ServerSocket(PORT);
            try {
                Socket socket = listener.accept();
                System.out.println("Connected on " + socket.toString());
                BufferedReader br = new BufferedReader(
                        new FileReader("/Users/jeromeboyer/Code/jbcodeforce/flink-studies/my-flink/data/avg.txt"));
                try {
                    PrintWriter outChannel = new PrintWriter(socket.getOutputStream(), AUTO_FLUSH);
                    String line = null;
                    while ((line = br.readLine()) != null) {
                        System.out.println("Send " + line);
                        outChannel.println(line);
                        Thread.sleep(50);
                    }
                } catch (InterruptedException e) {
                    e.printStackTrace();
                } finally {
                    socket.close();
                    br.close();
                }
            } finally {
                listener.close();
            }
        } catch (IOException e) {
            e.printStackTrace();
        }

    }
}

package IHM;

import java.awt.Color;
import java.awt.Dimension;
import java.awt.Graphics2D;
import java.awt.Image;
import java.awt.RenderingHints;
import java.awt.event.FocusEvent;
import java.awt.event.FocusListener;
import java.awt.image.BufferedImage;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Scanner;

import javax.swing.BorderFactory;
import javax.swing.JComponent;
import javax.swing.JFrame;
import javax.swing.JOptionPane;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;

import Applications.AbstractApp;

public final class Tools {
	private Tools() {
		//Do nothing
	}

	public static boolean isOSX() {
		String osName = System.getProperty("os.name");
		return osName.contains("OS X");
	}

	/**
	 * Add a red border to the component c
	 * May be used in tutorial, to highlight what component you have to use etc ...
	 * @param c
	 */
	public static void setRedBorder(JComponent c) {
		c.setBorder(BorderFactory.createLineBorder(Color.red));
	}

	public static String getArchiveExtension(String nomFichier) {
		String[] split = nomFichier.split("\\.");
		if (split.length >= 3) {
			return split[split.length - 2];
		} else {
			//System.out.println("The String does not contains two file extensions");
			return "";
		}
	}

	public static String getFileExtension(String nomFichier) {
		String[] split = nomFichier.split("\\.");
		if (split.length >= 2) {
			return split[split.length - 1];
		} else {
			//System.out.println("The String does not contains file extension");
			return "";
		}
	}

	public static int showConfirmMessage(JFrame f, String message) {
		int retour = JOptionPane.showConfirmDialog(
				f,
				message,
				"Warning",
				JOptionPane.YES_NO_OPTION
		);
		return retour;
	}

	public static void showLongMessage(JFrame f, String titre, String message) {
		JTextArea area = new JTextArea(message);
		area.setLineWrap(true);
		JScrollPane scroller = new JScrollPane(area);
		scroller.setPreferredSize(new Dimension(400, 400));
		JOptionPane.showMessageDialog(
				f,
				scroller,
				titre,
				JOptionPane.INFORMATION_MESSAGE
		);
	}

	public static void showMessage(JFrame f, String titre, String message) {
		JOptionPane.showMessageDialog(
				f,
				message,
				titre,
				JOptionPane.INFORMATION_MESSAGE
		);
	}

	public static void showErrorMessage(JFrame f, String message) {
		JTextArea area = new JTextArea(message);
		area.setLineWrap(true);
		JScrollPane scroller = new JScrollPane(area);
		scroller.setPreferredSize(new Dimension(400, 200));
		JOptionPane.showMessageDialog(
				f,
				scroller,
				"Error !",
				JOptionPane.ERROR_MESSAGE
		);
	}

	public static Image getScaledImage(Image srcImg, int w, int h){
	    BufferedImage resizedImg = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
	    Graphics2D g2 = resizedImg.createGraphics();
	
	    g2.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
	    g2.drawImage(srcImg, 0, 0, w, h, null);
	    g2.dispose();
	
	    return resizedImg;
	}

	static String twoLinesString(String str1, String str2) {
		if (str2.equals("")) {
			return "<html>" + str1 + "</html>";
		} else {
			return "<html>" + str1 + "<br />" + str2 + "</html>";
		}
	}
	
	/**
	 * If the path of the browser is "" show an error message
	 * @param f a frame to attach the potential errorMessage
	 * @param bro the browser to test
	 * @return true if the browser's path isn't ""
	 */
	public static boolean isReady(JFrame f, Browser bro) {
		if (bro.getPath().equals("")) {
			String str = "";
			if (bro.getParam() != null) {
				str = bro.getParam().key();
				String[] s = str.split(" ");
				str = s[s.length - 1] + " ";
			}
			showErrorMessage(f, "The " + str + "path isn't defined");
			return false;
		} else {
			return true;
		}
	}
	
	/**
	 * Catch the error stream, filter the log trace and write it in 
	 * path/logName file, check if there is an real error and if yes, 
	 * write it in a popup and return true. 
	 * @param proc : the Process where the script was executed
	 * @param path : the path to the result directory, where le logFile
	 * will be written.
	 * @param logName : the logfile name
	 * @param frame : the JFrame where the error popup will appear
	 * @return true if there is an error (excluding log trace)
	 * 		   false if not
	 */
	public static Boolean scriptError(Process proc, String path, String logName, JFrame frame) {
		String erreur = new String("");
		Scanner err = new Scanner(proc.getErrorStream());
		String log = new String("");
		while (err.hasNextLine()) {
			String tmperr = err.nextLine();
			if (tmperr.startsWith("+")) {
				log += tmperr + "\n";
			} else {
				erreur += tmperr + "\n";
			}
		}
		
		try {
			FileWriter writer = new FileWriter(path + "/" + logName, false); 
			writer.write(log);
			writer.close();
		} catch (IOException e) {
			e.printStackTrace();
		} 
		
		err.close();
		if (!erreur.equals("")) {
			String message = "**** SCRIPT ERROR ****\n"
							 + erreur
							 + "**** SCRIPT ERROR END ****\n";
			Tools.showErrorMessage(frame, message);
			return true;
		}
		
		return false;
	}
	
	/**
	 * Given an absolute file path, create a copy of this file
	 * in the file copypath
	 * in the temporary folder of the anacom module
	 * remove all empty lines
	 * @param filename
	 */
	public static void removeEmptyLines(String filename, String copypath) {
		File source = new File(filename);
		File dest = new File(copypath);
		
		FileReader fr = null;
		try {
			fr = new FileReader(source);
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} 

		FileWriter fw = null;
		try {
			fw = new FileWriter(dest);
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} 
		String line;
		BufferedReader br = new BufferedReader(fr); 
		if (fr == null || fw == null) {
			return;
		}
		try {
			while((line = br.readLine()) != null)
			{ 
			    String tmpLine = line.trim(); // remove leading and trailing whitespace
			    if (!tmpLine.equals("")) // don't write out blank lines
			    {
			        fw.write(line, 0, line.length());
			        String rc = "\n";
			        fw.write(rc, 0, rc.length());
			    }
			}
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} 
		try {
			fr.close();
			fw.close();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return;
	}
	
	public static void gatherRound(final AbstractApp app) {
		final BCBToolKitIHM bcb = app.getBCB();
		app.getFrame().addFocusListener(new FocusListener() {
			public void focusGained(FocusEvent e) {
				bcb.allOnFront();
				//app.getFrame().requestFocus();
				return;
			}

			public void focusLost(FocusEvent e) {
				return;
			}
		});
	}
}

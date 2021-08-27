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
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.io.Writer;

import javax.swing.BorderFactory;
import javax.swing.JComponent;
import javax.swing.JFrame;
import javax.swing.JOptionPane;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.SwingWorker;

import Applications.AbstractApp;

public final class Tools {
	public static int OSXOffset;
	private Tools() {
		//Do nothing
	}

	public static boolean isOSX() {
		String osName = System.getProperty("os.name");
		return osName.contains("OS X");
	}
	
	public static int getOffset() {
		if (isOSX()) {
			OSXOffset = 20;
		} else {
			OSXOffset = 0;
		}
		return OSXOffset;
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
	 * Search all error lines in the log file located in path
	 * @param path : the path of the log file you want to parse
	 * @return a String containing the error lines
	 */
	public static String parseLog(String path) {
		String erreur = "";
		File source = new File(path);
		BufferedReader br = null;
		try {
			br = new BufferedReader(new FileReader(source));
		} catch (FileNotFoundException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		

		try {
			for(String line; (line = br.readLine()) != null; ) {
				line = line.trim();
				if (!line.startsWith("+") && !line.matches("^\\W*$")) {
					erreur += line + "\n";
				}
			}
		} catch (IOException e) {
			e.printStackTrace();
		} 
		try {
			br.close();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return erreur;
	}
	
	/**
	 * Search all error lines in the log file located in path and strings in 
	 * ignore (or starting by those strings) will be ignored as errors
	 * A better way is to just store non-log lines and parse which are false error
	 * but by doing this we will gain maybe hundreds of milliseconds so ... 
	 * @param path
	 * @param ignore Strings that will be ignored as errors
	 * @param startWith a boolean that will say if the filtering use only the beginning of 
	 * strings contained in ignore or if strings have to fit totally
	 * @return
	 */
	public static String parseLog(String path, String[] ignore,  boolean startWith) {
		String erreur = "";
		File source = new File(path);
		BufferedReader br = null;
		try {
			br = new BufferedReader(new FileReader(source));
		} catch (FileNotFoundException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		

		try {
			for(String line; (line = br.readLine()) != null; ) {
				line = line.trim();
				boolean notAnError = false;
				for (String s : ignore) {
					String st = s.trim();
					if (startWith) {
						if (line.startsWith(st)) {
							notAnError = true;
						}
					} else {
						if (line.equals(st)) {
							notAnError = true;
						}
					}
				}
				
				if (!notAnError && !line.startsWith("+") && !line.matches("^\\W*$")) {
					erreur += line + "\n";
				}
			}
		} catch (IOException e) {
			e.printStackTrace();
		} 
		try {
			br.close();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return erreur;
	}

	public static void classicErrorHandling(JFrame frame, String error, String success) {
		if (!error.trim().equals("")) {
			String message = "**** SCRIPT ERROR ****\n"
					+ error
					+ "**** SCRIPT ERROR END ****\n";
			Tools.showErrorMessage(frame, message);
		} else {
			Tools.showMessage(frame, "End !", success);
		}
		return;
	}
	
	/**
	 * Given an absolute file path, create a copy of this file
	 * in copypath encoded in UTF-8 (to avoiding weird characters)
	 * It works only for parameter for anaCOM2 so csv files with 
	 * only one or two columns
	 * @param filename : The path of the source
	 *        copypath : The path of the destination
	 *        detZero  : True if we want to detect zeros in the source file
	 * @return boolean : -If you selected the zero's detection it will return
	 * 		true if the function found a zero, false if not
	 * 					 -If you don't want to detect zeros it will always 
	 * 		return false
	 * 
	 * WARNING : You can only make the zero's detection on files with the comma
	 * as cell's separator (like csv files) 
	 */
	public static boolean cleanCopy(String filename, String copypath, boolean detZero, JFrame frame) {
		boolean bool = false;
		File source = new File(filename);
		//Create the copy or erase the file with the same name
		try {
			FileWriter writer = new FileWriter(copypath, false); 
			writer.write("");
			writer.close();
		} catch (IOException e) {
			e.printStackTrace();
		}
		
		Writer out = null;
		try {
			out = new BufferedWriter(new OutputStreamWriter(
					new FileOutputStream(copypath), "UTF-8"));
		} catch (UnsupportedEncodingException e2) {
			// TODO Auto-generated catch block
			e2.printStackTrace();
		} catch (FileNotFoundException e2) {
			// TODO Auto-generated catch block
			e2.printStackTrace();
		}
		
		BufferedReader br = null;
		try {
			br = new BufferedReader(new FileReader(source));
		} catch (FileNotFoundException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		
		if (!detZero) {
			try {
				for(String line; (line = br.readLine()) != null; ) {
					out.write(line + "\n");
				}
			} catch (IOException e) {
				e.printStackTrace();
			} 
		
		} else {
			try {
				for(String line; (line = br.readLine()) != null; ) {
					//Here we will search for zeros
					//First we split cells in each line
					if (!bool) { //Just avoiding useless tests if we have already a zero
						String[] cells = line.split(",");
						boolean is_num = true;
						float num = 0;
						// We test if the first cell of the line is a number
						try {
					    	num = Float.parseFloat(cells[0]);
					    } catch (NumberFormatException e) {
					    	is_num = false;
					    }
						// If not we test if the second cell is
						if (!is_num) {
							try {
								is_num = true;
						    	num = Float.parseFloat(cells[1]);
						    } catch (NumberFormatException e) {
						      	is_num = false;
						    }
						}
						// If not we have a bad input so we go out of the function
						if (!is_num) {
							bool = true;
							return bool;
						}
						// If we have a number but <= 0 we leave the function
						if (num <= 0.0) {
							bool = true;
							return bool;
						}
					}
					// if all the line passed all the tests we write it in UTF8
					out.write(line + "\n");
				}
			} catch (IOException e) {
				e.printStackTrace();
			} 
		}
		
		try {
			out.close();
			br.close();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return bool;
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
	
	/**
	 * Removing temprary folder if there is a cancellation
	 * @param tmpPath the path of the temporary folder 
	 */
	public static void cancelActions(String tmpPath, SwingWorker<Void, Void> w) {
		w.cancel(true);
		w=null;
		if (tmpPath != null && !tmpPath.equals("")) {
			String[] array2 = {"rm", "-rf", tmpPath};
			try {
				Runtime.getRuntime().exec(array2);
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
	}
}

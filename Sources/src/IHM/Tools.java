package IHM;

import java.awt.Color;
import java.awt.Dimension;
import java.awt.Graphics2D;
import java.awt.Image;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;

import javax.swing.BorderFactory;
import javax.swing.JComponent;
import javax.swing.JFrame;
import javax.swing.JOptionPane;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;

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
	
}

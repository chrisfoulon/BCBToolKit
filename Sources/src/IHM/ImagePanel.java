package IHM;

import java.awt.Graphics;
import java.awt.Image;
import java.awt.LayoutManager;
import java.net.URL;

import javax.swing.ImageIcon;
import javax.swing.JPanel;

public class ImagePanel extends JPanel {
	private static final long serialVersionUID = 4041403012497464018L;
	private String path;
	private int w = 170;
	private int h = 92;
	/**
	 * Create a panel with an image as background  
	 * @pre
	 *  path != null && File(path).exists()
	 */
	public ImagePanel(String path) {
		super();
		this.path = path;
	}
	
	public ImagePanel(String path, LayoutManager layout) {
		super(layout);
		this.path = path;
	}
	
	public ImagePanel(String path, int w, int h) {
		super();
		this.path = path;
		this.w = w;
		this.h = h;
	}
	
	public void paintComponent(Graphics g) {
		super.paintComponent(g);
		URL url = getClass().getClassLoader().getResource(path);
		ImageIcon logo = new ImageIcon(url); 
		Image bg = Tools.getScaledImage(logo.getImage(), w, h);
		int x = (this.getWidth() - bg.getWidth(null)) / 2;
        g.drawImage(bg, x, 10, null);
	} 
}

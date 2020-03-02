package IHM;

import java.awt.Dimension;

import javax.swing.JProgressBar;

public class LoadingBar extends JProgressBar {
	private static final long serialVersionUID = 2562038990302023057L;
	
	private int width = 0;
	private int nbTicks = 0;
	
	public LoadingBar() {
		super(0, 100);
		setPreferredSize(new Dimension(300, 20));
		//Display a text on the loadingBar
		this.setStringPainted(true);
		this.setString("Still running");
	}
	
	public int getNbTicks() {
		return nbTicks;
	}
	
	public void setWidth(int w) {
		if (w == 0) {
			//Dessine une petite partie de la barre
			width = 1;
		} else {
			width = Math.round((float) w/getNbTicks() * 100);
		}
		setValue(width);
	}
	
	public void setNbTicks(int nb) {
		nbTicks = nb;
	}
}

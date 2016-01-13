package Applications;

import java.awt.Point;

import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.SwingWorker;

import Config.BCBEnum;
import Config.Config;
import IHM.BCBToolKitIHM;

public abstract class AbstractApp {
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 500;
	public static final int ICON_PADDING = 4;
	public static final int INFRAME_PADDING = 20;
	public static final int LINE_HEIGHT = 20;
	protected JFrame frame;
	protected String path;
	protected Config conf;
	protected BCBToolKitIHM bcb;
	protected final BCBEnum.Index index;

	//The swingWorker : a thread that will execute the script
	SwingWorker<Void, Void> worker = null;

	public AbstractApp(String path, BCBToolKitIHM b, BCBEnum.Index in) {
		this.setPath(path);
		this.conf = b.getConfig();
		this.bcb = b;
		this.index = in;
		createView();
		placeComponents();
		createControllers();
		createModel();
	}

	//COMMANDES
	public void display() {
		frame.pack();
		if (!conf.getVal(this.index.name()).equals("")) {
			getBCB().setCustomLocation(frame, this.index);
		} else {
			frame.setLocationRelativeTo(null);
		}
		frame.setVisible(true);
	}

	abstract void createModel();

	abstract void createView();
	
	abstract void placeComponents();

	abstract void createControllers();

	//OUTILS	

	//Modifications des composants
	abstract void changeRunButton(JPanel p, int state);

	public BCBToolKitIHM getBCB() {
		return bcb;
	}

	public JFrame getFrame() {
		return this.frame;
	}

	public Point getLocation() {
		return frame.getLocationOnScreen();
	}

	public String getPath() {
		return path;
	}
	
	public Config getConf() {
		return conf;
	}

	private void setPath(String path) {
		this.path = path;
	}

	public void cancel() {
		if (worker != null) {
			worker.cancel(true);
		}
	}

	public void closing() {
		getBCB().addLoc(this.index, this.getLocation());
		getBCB().closingApp();
		frame.setVisible(false);
	}

	public void shutDown() {
		cancel();
		frame.dispose();
	}
}

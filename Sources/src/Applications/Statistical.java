package Applications;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.awt.Point;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.File;
import java.net.URL;

import javax.swing.Icon;
import javax.swing.ImageIcon;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.SwingWorker;

import Config.BCBEnum;
import Config.Config;
import IHM.BCBToolKitIHM;
import IHM.Browser;
import IHM.ImagePanel;
import IHM.LoadingBar;
import Models.StatisticalModel;

public class Statistical {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 410;
	// Ecart entre l'icone et les bordure des boutons. 
	public static final int ICON_PADDING = 4;
	public static final int INFRAME_PADDING = 20;
	public static final int LINE_HEIGHT = 20;
	public static final String HYPER_TITLE = "Statistical Analysis";
	private JFrame frame;
	private ImagePanel background;
	private JPanel panel;
	private JPanel topP;
	private JButton settings;
	private JButton run;
	private LoadingBar loading;
	private StatisticalModel model;
	private String path;
	private Config conf;

	private BCBToolKitIHM bcb;

	//Browsers
	private Browser map1Bro;
	private Browser map2Bro;
	private Browser resBro;

	//The swingWorker : a thread that will execute the script
	SwingWorker<Void, Void> worker = null;

	public Statistical(String path, BCBToolKitIHM b) {
		this.path = path;
		this.conf = b.getConfig();
		this.bcb = b;
		createModel();
		createView();
		placeComponents();
		createController();
	}

	//COMMANDES
	public void display() {
		frame.pack();
		if (!conf.getVal(BCBEnum.Index.DISCONNECTOME.name()).equals("")) {
			getBCB().setCustomLocation(frame, BCBEnum.Index.DISCONNECTOME);
		} else {
			frame.setLocationRelativeTo(null);
		}
		frame.setVisible(true);
	}

	private void createModel() {
		model = new StatisticalModel(path, this.getFrame());
	}

	private void createView() {
		//Frame
		frame = new JFrame(HYPER_TITLE); {
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setResizable(false);
			display();
		}
		background = new ImagePanel("LogoT.png");
		background.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT * 5));
		//Cr��ation des icones
		URL url = getClass().getClassLoader().getResource("settings.png");
		Icon setIco = new ImageIcon(url); 
		int setIcoW = setIco.getIconWidth();
		//Cr��ation des boutons
		int padding = 0;
		if (!isOSX()) {
			padding = -5;
		}
		settings = new JButton(setIco);
		settings.setPreferredSize(new Dimension(setIcoW + ICON_PADDING, setIcoW + ICON_PADDING + padding));
		settings.setToolTipText("Settings");

		run = new JButton("RUN");
		run.setPreferredSize(new Dimension(FRAME_WIDTH - 20, 45));
		//Tests browsers
		map1Bro = new Browser(frame, "First Maps directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.SMAP1DIR, getBCB());
		map1Bro.setDefPath(System.getProperty("user.home"));
		map1Bro.firstReset();
		getBCB().addBro(map1Bro.getParam(), map1Bro);
		map2Bro = new Browser(frame, "Second Maps directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.SMAP2DIR, getBCB());
		map2Bro.setDefPath(System.getProperty("user.home"));
		map2Bro.firstReset();
		getBCB().addBro(map2Bro.getParam(), map2Bro);
		resBro = new Browser(frame, "Results directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.SRESDIR, getBCB());
		resBro.setDefPath(System.getProperty("user.home"));
		resBro.firstReset();
		getBCB().addBro(resBro.getParam(), resBro);
	}

	private void placeComponents() {			
		JPanel top = new JPanel(new FlowLayout(FlowLayout.RIGHT)); {
			top.add(settings);
		}
		JPanel center = new JPanel(new GridLayout(3, 0)); {
			center.add(map1Bro);
			center.add(map2Bro);
			center.add(resBro);
		}
		topP = new JPanel(new FlowLayout(FlowLayout.CENTER));
		topP.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT));
		frame.add(topP);
		frame.add(background, BorderLayout.NORTH);
		frame.add(center, BorderLayout.CENTER);
		// Panel contenant la checkBox
		JPanel r1 = new JPanel(new FlowLayout(FlowLayout.RIGHT)); {
			r1.add(settings);
			r1.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT));
		}
		// Panel du bouton run
		panel = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
			panel.add(run);
			panel.setMinimumSize(new Dimension(FRAME_WIDTH - 20, 55));
			panel.setPreferredSize(new Dimension(FRAME_WIDTH - 20, 55));
		}
		JPanel south = new JPanel(new GridLayout(2, 0)); {
			south.add(r1, 0, 0);
			south.add(panel, 0, 1);
		}
		frame.add(south, BorderLayout.SOUTH);
	}

	private void createController() {	
		frame.addWindowListener(new WindowAdapter(){
			public void windowClosing(WindowEvent e) {
				closing();
			}
		});

		settings.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				getBCB().openSettings(BCBEnum.Index.STATISTICAL);
			}
		});

		run.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				worker = new SwingWorker<Void, Void>() {
					@Override
					public Void doInBackground() {
						model.setMap1Dir(map1Bro.getPath());
						model.setMap2Dir(map2Bro.getPath());
						model.setResultDir(resBro.getPath());
						model.hyperRun();
						return null;
					}
					@Override
					protected void done() {
						changeRunButton(panel, 1);
					}
				};
				changeRunButton(panel, 0);
				worker.execute();

			}
		});
	}

	//OUTILS
	public static String getFileExtension(String nomFichier) {
		File tmpFichier = new File(nomFichier);
		tmpFichier.getName();
		int posPoint = tmpFichier.getName().lastIndexOf('.');
		if (0 < posPoint && posPoint <= tmpFichier.getName().length() - 2) {
			return tmpFichier.getName().substring(posPoint + 1);
		} else {
			return "";
		}
	}

	//Modifications des composants
	private void changeRunButton(JPanel p, int state) {
		// 0 = lancement de run() 1 = Fin de run()
		if (state == 0) {
			loading = new LoadingBar();
			p.remove(run);
			loading.setToolTipText("Loading");
			p.add(loading);
			model.setLoadingBar(loading);
			loading.setWidth(0);
			p.repaint();
			p.revalidate();
		} else if (state == 1) {
			p.remove(loading);
			p.add(run);
			p.repaint();
			p.revalidate();
		} else {
			return;
		}
	}

	public BCBToolKitIHM getBCB() {
		return bcb;
	}

	public JFrame getFrame() {
		return this.frame;
	}

	public static boolean isOSX() {
		String osName = System.getProperty("os.name");
		return osName.contains("OS X");
	}

	public Point getLocation() {
		return frame.getLocationOnScreen();
	}

	public void cancel() {
		if (worker != null) {
			getBCB().cancelActions(path + "/Tools/tmp/tmpHyp", worker);
		}
	}

	public void closing() {
		getBCB().addLoc(BCBEnum.Index.STATISTICAL, this.getLocation());
		getBCB().closingApp();
		frame.setVisible(false);
	}

	public void shutDown() {
		cancel();
		frame.dispose();
	}
}

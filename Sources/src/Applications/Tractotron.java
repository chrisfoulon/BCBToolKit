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
import IHM.Tools;
import Models.TractoModel;


public class Tractotron {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 360;
	// Ecart entre l'icone et les bordure des boutons. 
	public static final int ICON_PADDING = 4;
	public static final int LINE_HEIGHT = 20;
	public static final String TRACTO_TITLE = "Tractotron";
	public static final String HYPER_TITLE = "Hypertron";
	public static final String DEF_LES = "/Lesions";
	public static final String DEF_TRA = "/Tracts";
	public static final String DEF_RES = "/Example.xls";
	private JFrame frame;
	private ImagePanel background;
	private JPanel panel;
	private JPanel topP;
	private JButton settings;
	private JButton run;
	//private JCheckBox checkBox;
	//private JLabel checkLbl;
	private LoadingBar loading;
	private TractoModel model;
	private String path;
	private Config conf;

	private BCBToolKitIHM bcb;

	//Browsers
	private Browser lesBro;
	private Browser traBro;
	private Browser resBro;

	//The swingWorker : a thread that will execute the script
	SwingWorker<Void, Void> worker = null;

	public Tractotron(String path, BCBToolKitIHM b) {
		this.path = path;
		this.conf = b.getConfig();
		this.bcb = b;
		createView();
		placeComponents();
		createControllers();
		createModel();
	}

	//COMMANDES
	public void display() {
		frame.pack();
		if (!conf.getVal(BCBEnum.Index.TRACTOTRON.name()).equals("")) {
			getBCB().setCustomLocation(frame, BCBEnum.Index.TRACTOTRON);
		} else {
			frame.setLocationRelativeTo(null);
		}
		frame.setVisible(true);
	}

	private void createModel() {
		model = new TractoModel(path, getFrame());
	}

	private void createView() {
		//Frame
		frame = new JFrame(TRACTO_TITLE); {
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setResizable(false);
			display();
		}
		background = new ImagePanel("tracto.png", 170, 92);
		background.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT * 5));
		//Création des icones
		URL url = getClass().getClassLoader().getResource("settings.png");
		Icon setIco = new ImageIcon(url); 
		int setIcoW = setIco.getIconWidth();
		//Création des boutons
		int padding = 0;
		if (!Tools.isOSX()) {
			padding = -5;
		}
		settings = new JButton(setIco);
		settings.setPreferredSize(new Dimension(setIcoW + ICON_PADDING, setIcoW + ICON_PADDING + padding));
		settings.setToolTipText("Settings");

		run = new JButton("RUN");
		run.setPreferredSize(new Dimension(FRAME_WIDTH - 10, 45));
		//checkLbl = new JLabel("Systematically replace contents");
		//checkLbl.setForeground(new Color(255, 0, 0));

		//La checkbox
		//checkBox = new JCheckBox();
		//checkBox.setSelected(true);
		//Browsers
		lesBro = new Browser(frame, "Lesions directory :", BCBEnum.fType.DIR.a(), conf, BCBEnum.Param.TLESDIR, getBCB());
		lesBro.setDefPath(path + getDefaultLesions());
		traBro = new Browser(frame, "Tracts directory :", BCBEnum.fType.DIR.a(), conf, BCBEnum.Param.TTRADIR, getBCB());
		traBro.setDefPath(path + getDefaultTracts());

		resBro = new Browser(frame, "Save tractotron result as .xls :", BCBEnum.fType.XLS.a(), conf, 
				BCBEnum.Param.TRESDIR, getBCB());
		resBro.setDefPath(path + getDefaultResult());

		lesBro.firstReset();
		traBro.firstReset();
		resBro.firstReset();
		// On ajoute les browser à la map de la bcbtb
		getBCB().addBro(lesBro.getParam(), lesBro);
		getBCB().addBro(traBro.getParam(), traBro);
		getBCB().addBro(resBro.getParam(), resBro);
	}

	private void placeComponents() {			
		JPanel top = new JPanel(new FlowLayout(FlowLayout.RIGHT)); {
			top.add(settings);
		}
		JPanel center = new JPanel(new GridLayout(3, 0)); {
			center.add(lesBro);
			center.add(traBro);
			center.add(resBro);
		}
		topP = new JPanel(new FlowLayout(FlowLayout.CENTER));
		topP.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT));
		frame.add(topP);
		frame.add(background, BorderLayout.NORTH);
		frame.add(center, BorderLayout.CENTER);
		// Panel contenant les deux checkbox
		JPanel r1 = new JPanel(new FlowLayout(FlowLayout.RIGHT)); {
			//r1.add(checkBox);
			//r1.add(checkLbl);
			r1.add(settings);
		}
		// Panel du bouton run
		panel = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
			panel.add(run);
			panel.setPreferredSize(new Dimension(FRAME_WIDTH - 10, 55));
		}
		JPanel south = new JPanel(new FlowLayout(FlowLayout.RIGHT)); {
			south.add(r1);
			south.add(panel);
		}
		int vgap = 0;
		if (Tools.isOSX()) {
			vgap = 10;
		}
		south.setPreferredSize(new Dimension(FRAME_WIDTH, 55 + 45 + vgap));		
		frame.add(south, BorderLayout.SOUTH);
	}

	private void createControllers() {	
		frame.addWindowListener(new WindowAdapter(){
			public void windowClosing(WindowEvent e) {
				closing();
			}
		});

		run.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				worker = new SwingWorker<Void, Void>() {
					@Override
					public Void doInBackground() {
						// Partie TRACTOTRON
						/*if (!checkBox.isSelected()) {
							int retour = BCBToolBoxIHM.showConfirmMessage(frame, 
									"The content of the result file will be replaced "
											+ "would you continue ?");
							if (retour == JOptionPane.NO_OPTION) {
								return null;
							}
						}*/
						if (Tools.isReady(frame, lesBro)) {
							model.setLesionDir(lesBro.getPath());
						} else {
							return null;
						}
						if (Tools.isReady(frame, traBro)) {
							model.setTractsDir(traBro.getPath());
						} else {
							return null;
						}
						if (Tools.isReady(frame, resBro)) {
							model.setResult(resBro.getFile());
						} else {
							return null;
						}
						
						model.run();
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

		settings.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				getBCB().openSettings(BCBEnum.Index.NORMALISATION);
			}
		});
	}

	//OUTILS	

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

	//Utilis�� pour le dossier par d��faut de l��sions.
	public static String getDefaultLesions() {
		return DEF_LES;
	}

	//Utilis�� pour le dossier par d��faut de tracts.
	public static String getDefaultTracts() {
		return DEF_TRA;
	}

	//Utilis�� pour le fichier de r��sultat par d��faut.
	public static String getDefaultResult() {
		return DEF_RES;
	}

	// GET functions for textfields
	public String getLesPath() {
		return lesBro.getPath();
	}

	public File getLesDir() {
		return lesBro.getFile();
	}

	public String getTraPath() {
		return traBro.getPath();
	}

	public File getTraDir() {
		return traBro.getFile();
	}

	public String getResPath() {
		return resBro.getPath();
	}

	public File getResFile() {
		return resBro.getFile();
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
			getBCB().cancelActions(path + "/Tools/tmp/multresh", worker);
		}
	}

	public void closing() {
		getBCB().addLoc(BCBEnum.Index.TRACTOTRON, this.getLocation());
		getBCB().closingApp();
		frame.setVisible(false);
	}

	public void shutDown() {
		cancel();
		frame.dispose();
	}
}

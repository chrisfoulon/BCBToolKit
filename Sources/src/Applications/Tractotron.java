package Applications;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridLayout;
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
import IHM.BCBToolKitIHM;
import IHM.Browser;
import IHM.ImagePanel;
import IHM.LoadingBar;
import IHM.Tools;
import Models.TractoModel;


public class Tractotron extends AbstractApp {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 360;
	// Ecart entre l'icone et les bordure des boutons. 
	public static final int ICON_PADDING = 4;
	public static final int LINE_HEIGHT = 20;
	public static final String TRACTO_TITLE = "Tractotron";
	public static final String DEF_LES = "/Lesions";
	public static final String DEF_TRA = "/Tracts";
	private ImagePanel background;
	private JPanel panel;
	private JPanel topP;
	private JButton settings;
	private JButton run;
	//private JCheckBox checkBox;
	//private JLabel checkLbl;
	private LoadingBar loading;
	private TractoModel model;

	//Browsers
	private Browser lesBro;
	private Browser traBro;
	private Browser resBro;

	public Tractotron(String path, BCBToolKitIHM b) {
		super(path, b, BCBEnum.Index.TRACTOTRON);
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

	protected void createModel() {
		model = new TractoModel(this.path, getFrame());
	}

	protected void createView() {
		//Frame
		frame = new JFrame(TRACTO_TITLE); {
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setResizable(false);
			display();
			frame.setFocusable(true);
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
		
		//Browsers
		lesBro = new Browser(this.getFrame(), "Lesions directory :", BCBEnum.fType.DIR.a(), this.getConf(), 
				BCBEnum.Param.TLESDIR, this.getBCB());
		lesBro.setDefPath(path + getDefaultLesions());
		traBro = new Browser(this.getFrame(), "Tracts directory :", BCBEnum.fType.DIR.a(), this.getConf(), 
				BCBEnum.Param.TTRADIR, this.getBCB());
		traBro.setDefPath(path + getDefaultTracts());
		resBro = new Browser(this.getFrame(), "Result directory :", BCBEnum.fType.DIR.a(),
				this.getConf(), BCBEnum.Param.TRESDIR, this.getBCB());

		lesBro.firstReset();
		traBro.firstReset();
		// On ajoute les browser à la map de la bcbtb
		getBCB().addBro(lesBro.getParam(), lesBro);
		getBCB().addBro(traBro.getParam(), traBro);
		getBCB().addBro(resBro.getParam(), resBro);
	}

	protected void placeComponents() {
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

	protected void createControllers() {
		Tools.gatherRound(this);
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
							model.setResultDir(resBro.getPath());
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
				getBCB().openSettings(BCBEnum.Index.TRACTOTRON);
			}
		});
	}

	//OUTILS	

	//Modifications des composants
	protected void changeRunButton(JPanel p, int state) {
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

	//Utilis�� pour le dossier par d��faut de l��sions.
	public String getDefaultLesions() {
		return DEF_LES;
	}

	//Utilis�� pour le dossier par d��faut de tracts.
	public String getDefaultTracts() {
		return DEF_TRA;
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
	
	@Override
	public void cancel() {
		if (worker != null) {
			Tools.cancelActions(path + "/Tools/tmp/multresh", worker);
		}
	}
	
	@Override
	public void stopProcess() {
		model.stopProcess();
	}
}

package Applications;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
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
import javax.swing.JCheckBox;
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
import Models.CorticalModel;

public class Cortical {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 330;
	// Ecart entre l'icone et les bordure des boutons. 
	public static final int ICON_PADDING = 4;
	public static final int INFRAME_PADDING = 20;
	public static final int LINE_HEIGHT = 20;
	public static final String CORTI_TITLE = "Cortical thickness";
	private JFrame frame;
	private ImagePanel background;
	private JPanel panel;
	private JButton settings;
	private JButton run;
	private LoadingBar loading;
	private CorticalModel model;
	private String path;
	private Config conf;
	private JCheckBox saveTmp;

	private BCBToolKitIHM bcb;

	//Browsers
	private Browser t1Bro;
	private Browser resBro;

	//The swingWorker : a thread that will execute the script
	SwingWorker<Void, Void> worker = null;

	public Cortical(String path, BCBToolKitIHM b) {
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
		if (!conf.getVal(BCBEnum.Index.CORTICAL.name()).equals("")) {
			getBCB().setCustomLocation(frame, BCBEnum.Index.CORTICAL);
		} else {
			frame.setLocationRelativeTo(null);
		}
		frame.setVisible(true);
	}

	private void createModel() {
		model = new CorticalModel(path, this.getFrame());
	}

	private void createView() {
		//Frame
		frame = new JFrame(CORTI_TITLE); {
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setResizable(false);
			display();
		}
		background = new ImagePanel("corti.png", 141, 93);
		background.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT * 5));
		//Cr��ation des icones
		URL url = getClass().getClassLoader().getResource("settings.png");
		Icon setIco = new ImageIcon(url); 
		int setIcoW = setIco.getIconWidth();
		//Cr��ation des boutons
		int padding = 0;
		if (!Tools.isOSX()) {
			padding = -5;
		}
		settings = new JButton(setIco);
		settings.setPreferredSize(new Dimension(setIcoW + ICON_PADDING, setIcoW + 
				ICON_PADDING + padding));
		settings.setToolTipText("Settings");

		run = new JButton("RUN");
		run.setPreferredSize(new Dimension(FRAME_WIDTH - 10, 45));
		t1Bro = new Browser(frame, "T1 directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.T1DIR, getBCB());

		getBCB().addBro(t1Bro.getParam(), t1Bro);

		resBro = new Browser(frame, "Results directory :", BCBEnum.fType.DIR.a(),
				conf, BCBEnum.Param.CRESDIR, getBCB());
		getBCB().addBro(resBro.getParam(), resBro);

		saveTmp = new JCheckBox("Keep temporary files");
		saveTmp.setPreferredSize(new Dimension(260, 20));
		saveTmp.setIconTextGap(20);
		saveTmp.setSelected(conf.getVal(BCBEnum.Param.CSAVETMP).equals("true"));
	}

	private void placeComponents() {
		JPanel center = new JPanel(new BorderLayout()); {
			center.add(t1Bro, BorderLayout.NORTH);
			center.add(resBro, BorderLayout.SOUTH);
		}
		frame.add(background, BorderLayout.NORTH);
		frame.add(center, BorderLayout.CENTER);
		// Panel contenant la checkBox
		JPanel r1 = new JPanel(new FlowLayout(FlowLayout.RIGHT)); {
			r1.add(saveTmp);
			r1.add(settings);
		}
		// Panel du bouton run
		panel = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
			panel.add(run);
			panel.setPreferredSize(new Dimension(FRAME_WIDTH - 10, 55));
		}
		JPanel south = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
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

	private void createController() {	
		frame.addWindowListener(new WindowAdapter(){
			public void windowClosing(WindowEvent e) {
				closing();
			}
		});

		settings.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				getBCB().openSettings();
			}
		});

		run.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				worker = new SwingWorker<Void, Void>() {
					@Override
					public Void doInBackground() {
						if (Tools.isReady(frame, t1Bro)) {
							model.setT1Dir(t1Bro.getPath());
						} else {
							return null;
						}
						if (Tools.isReady(frame, resBro)) {
							model.setResultDir(resBro.getPath());
						} else {
							return null;
						}
						model.run(new Boolean(saveTmp.isSelected()));
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

		saveTmp.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				if (saveTmp.isSelected()) {
					conf.setVal(BCBEnum.Param.CSAVETMP, "true");
				} else {
					conf.setVal(BCBEnum.Param.CSAVETMP, "false");
				}
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

	public Point getLocation() {
		return frame.getLocationOnScreen();
	}

	public void cancel() {
		if (worker != null) {
			worker.cancel(true);
		}
	}

	public void closing() {
		getBCB().addLoc(BCBEnum.Index.CORTICAL, this.getLocation());
		getBCB().closingApp();
		frame.setVisible(false);
	}

	public void shutDown() {
		cancel();
		frame.dispose();
	}
}

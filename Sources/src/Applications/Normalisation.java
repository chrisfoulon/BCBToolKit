package Applications;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.awt.Insets;
import java.awt.Point;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.File;
import java.net.URL;
import java.util.ArrayList;

import javax.swing.Icon;
import javax.swing.ImageIcon;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.SwingWorker;

import Config.BCBEnum;
import Config.BCBEnum.fType;
import IHM.BCBToolKitIHM;
import IHM.Browser;
import IHM.ImagePanel;
import IHM.LoadingBar;
import IHM.Tools;
import Models.NormalisationModel;

public class Normalisation extends AbstractApp {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 500;
	// Ecart entre l'icone et les bordure des boutons. 
	public static final int ICON_PADDING = 4;
	public static final int LINE_HEIGHT = 20;
	public static final String NORMA_TITLE = "Normalisation";
	public static final String DEFAULT_TEMPLATE = "/Tools/extraFiles/MNI152.nii.gz";

	private ImagePanel background;
	private JPanel panel;
	private JPanel othP;
	private JButton settings;
	private JButton run;
	private LoadingBar loading;
	private NormalisationModel model;

	//Browsers
	private Browser tempBro;
	private Browser t1Bro;
	private Browser lesBro;
	private Browser resBro;
	//A checkBox to choose to apply transformation to other files
	private JCheckBox otherCheck;
	
	private JCheckBox saveTmp;
	//Optionnal browsers 
	private Browser othBro;
	private Browser othResBro;

	public Normalisation(String path, BCBToolKitIHM b) {
		super(path, b, BCBEnum.Index.NORMALISATION);
	}

	//COMMANDES
	public void display() {
		frame.pack();
		if (!conf.getVal(BCBEnum.Index.NORMALISATION.name()).equals("")) {
			getBCB().setCustomLocation(frame, BCBEnum.Index.NORMALISATION);
		} else {
			frame.setLocationRelativeTo(null);
		}
		frame.setVisible(true);
	}

	protected void createModel() {
		model = new NormalisationModel(path, getFrame());
	}

	protected void createView() {
		//Frame
		frame = new JFrame(NORMA_TITLE); {
			frame.setMinimumSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setMaximumSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT + 100));
			frame.setResizable(false);
			display();
			frame.setFocusable(true);
		}
		background = new ImagePanel("norma.png", 140, 112);
		background.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT * 6));
		//Création des icones
		URL url = getClass().getClassLoader().getResource("settings.png");
		Icon setIco = new ImageIcon(url); 
		int setIcoW = setIco.getIconWidth();
		//Création des boutons
		int padding = 0;
		int leftOthCheck = 3;
		if (!Tools.isOSX()) {
			padding = -5;
			leftOthCheck = 0;
		}
		settings = new JButton(setIco);
		settings.setPreferredSize(new Dimension(setIcoW + ICON_PADDING, setIcoW + ICON_PADDING + padding));
		settings.setToolTipText("Settings");

		run = new JButton("RUN");
		run.setPreferredSize(new Dimension(FRAME_WIDTH - 10, 45));
		//Browsers
		//We need nii and nii.gz extension for the template browser.
		ArrayList<fType> arr = fType.NII.a();
		arr.add(fType.NIIGZ);
		tempBro = new Browser(frame, "Template directory :", arr, 
				conf, BCBEnum.Param.NTEMPDIR, getBCB());
		tempBro.setDefPath(this.path + DEFAULT_TEMPLATE);
		tempBro.firstReset();

		getBCB().addBro(tempBro.getParam(), tempBro);

		t1Bro = new Browser(frame, "T1 directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.NT1DIR, getBCB());

		getBCB().addBro(t1Bro.getParam(), t1Bro);

		lesBro = new Browser(frame, "[Optional]Lesions directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.NLESDIR, getBCB());

		getBCB().addBro(lesBro.getParam(), lesBro);
		resBro = new Browser(frame, "Result directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.NRESDIR, getBCB());

		getBCB().addBro(resBro.getParam(), resBro);

		otherCheck = new JCheckBox("Apply transformations to other");
		otherCheck.setSelected(false);
		otherCheck.setIconTextGap(20);
		otherCheck.setMargin(new Insets(0, leftOthCheck, 0, 0));

		othBro = new Browser(frame, "Other directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.NOTHDIR, getBCB());

		getBCB().addBro(othBro.getParam(), othBro);

		othResBro = new Browser(frame, "Other result directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.NOTHRESDIR, getBCB());

		getBCB().addBro(othResBro.getParam(), othResBro);
		
		saveTmp = new JCheckBox("Keep temporary files");
		saveTmp.setPreferredSize(new Dimension(260, 20));
		saveTmp.setIconTextGap(20);
		saveTmp.setSelected(conf.getVal(BCBEnum.Param.CSAVETMP).equals("true"));
		saveTmp.setMargin(new Insets(0, 0, 0, 0));
	}

	protected void placeComponents() {
		//NORTH
		frame.add(background, BorderLayout.NORTH);

		JPanel middle = new JPanel(new BorderLayout(5, 0)); {
			JPanel center = new JPanel(new GridLayout(4, 0)); {
				center.add(tempBro);
				center.add(t1Bro);
				center.add(lesBro);
				center.add(resBro);
			}
			middle.add(center, BorderLayout.NORTH);
			JPanel flow = new JPanel(new FlowLayout(FlowLayout.LEFT)); {
				flow.add(otherCheck);
			}
			middle.add(flow, BorderLayout.CENTER);
			//This panel will receive additionnal browsers
			othP = new JPanel(new GridLayout(0, 1));
			middle.add(othP, BorderLayout.SOUTH);
		}
		frame.add(middle, BorderLayout.CENTER);


		//SOUTH
		// Panel contenant les deux checkbox
		JPanel r1 = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
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
						if (Tools.isReady(frame, tempBro)) {
							model.setTempFile(tempBro.getPath());
						} else {
							return null;
						}
						if (Tools.isReady(frame, t1Bro)) {
							model.setT1Dir(t1Bro.getPath());
						} else {
							return null;
						}
						//This path could be empty if you want to just normalize a T1
						model.setLesionDir(lesBro.getPath());
						if (Tools.isReady(frame, resBro)) {
							model.setResultDir(resBro.getPath());
						} else {
							return null;
						}
						// Setting the brain extraction threshold
						model.setBetOpt(conf.getVal(BCBEnum.Param.NBETOPT));
						// Should we save temporary files
						if (saveTmp.isSelected()) {
							model.setSaveTmp("true");
						} else {
							model.setSaveTmp("false");
						}
						
						if (otherCheck.isSelected()) {
							if (Tools.isReady(frame, othBro)) {
								model.setOthDir(othBro.getPath());
							} else {
								return null;
							}
							if (Tools.isReady(frame, othResBro)) {
								model.setOthResDir(othResBro.getPath());
							} else {
								return null;
							}
						}

						model.run(otherCheck.isSelected());
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

		otherCheck.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				if (otherCheck.isSelected()) {
					frame.setPreferredSize(frame.getMaximumSize());
					othP.add(othBro);
					othP.add(othResBro);
				} else {
					othP.remove(othBro);
					othP.remove(othResBro);
					frame.setPreferredSize(frame.getMinimumSize());
				}
				frame.validate();
				frame.repaint();
				frame.pack();
			}
		});
		
		saveTmp.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				if (saveTmp.isSelected()) {
					conf.setVal(BCBEnum.Param.NSAVETMP, "true");
				} else {
					conf.setVal(BCBEnum.Param.NSAVETMP, "false");
				}
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

	// GET functions for textfields
	public String getLesPath() {
		return lesBro.getPath();
	}

	public File getLesDir() {
		return lesBro.getFile();
	}

	public String getT1Path() {
		return t1Bro.getPath();
	}

	public File getT1Dir() {
		return t1Bro.getFile();
	}

	public String getTempPath() {
		return tempBro.getPath();
	}

	public File getTempFile() {
		return tempBro.getFile();
	}

	public String getResPath() {
		return resBro.getPath();
	}

	public File getResDir() {
		return resBro.getFile();
	}

	public String getOthPath() {
		return othBro.getPath();
	}

	public File getOthDir() {
		return othBro.getFile();
	}

	public String getOthResPath() {
		return othResBro.getPath();
	}

	public File getOthResDir() {
		return othResBro.getFile();
	}

	public Point getLocation() {
		return frame.getLocationOnScreen();
	}

	@Override
	public void cancel() {
		if (worker != null) {
			getBCB().cancelActions(path + "/Tools/tmp/tmpNorm", worker);
		}
	}
}

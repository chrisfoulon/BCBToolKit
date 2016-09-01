package Applications;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.awt.Insets;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.net.URL;

import javax.swing.Icon;
import javax.swing.ImageIcon;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JComboBox;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SwingWorker;

import Config.BCBEnum;
import IHM.BCBToolKitIHM;
import IHM.Browser;
import IHM.ImagePanel;
import IHM.LoadingBar;
import IHM.Tools;
import Models.RestingModel;

public class Resting extends AbstractApp {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 500;
	// Ecart entre l'icone et les bordure des boutons. 
	public static final int ICON_PADDING = 4;
	public static final int INFRAME_PADDING = 20;
	public static final int LINE_HEIGHT = 20;
	public static final String RESTING_TITLE = "Resting State";
	private ImagePanel background;
	private JPanel panel;
	private JButton settings;
	private JButton run;
	private LoadingBar loading;
	private RestingModel model;
	private JComboBox<String> sliceCombo;
	
	private JCheckBox saveTmp;

	//Browsers
	private Browser T1Bro;
	private Browser RSBro;
	private Browser lesBro;
	private Browser resBro;

	public Resting(String path, BCBToolKitIHM b) {
		super(path, b, BCBEnum.Index.RESTING);
	}

	//COMMANDES
	public void display() {
		frame.pack();
		if (!conf.getVal(BCBEnum.Index.DISCONNECTOME.name()).equals("")) {
			getBCB().setCustomLocation(frame, BCBEnum.Index.RESTING);
		} else {
			frame.setLocationRelativeTo(null);
		}
		frame.setVisible(true);
	}

	protected void createModel() {
		model = new RestingModel(path, this.getFrame());
	}

	protected void createView() {
		//Frame
		frame = new JFrame(RESTING_TITLE); {
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setResizable(false);
			display();
			frame.setFocusable(true);
		}
		background = new ImagePanel("Brain.jpg", 140, 112);
		background.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT * 6));
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
		settings.setPreferredSize(new Dimension(setIcoW + ICON_PADDING, 
				setIcoW + ICON_PADDING + padding));
		settings.setToolTipText("Settings");

		run = new JButton("RUN");
		run.setPreferredSize(new Dimension(FRAME_WIDTH - 10, 45));

		//Tests browsers
		T1Bro = new Browser(frame, "T1 images directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.RT1DIR, getBCB());
		T1Bro.setToolTipText("T1 images must have the same name as Resting state images");

		getBCB().addBro(T1Bro.getParam(), T1Bro);
		
		RSBro = new Browser(frame, "Resting State directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.RRSDIR, getBCB());
		RSBro.setToolTipText("Resting stats images must have the same name as T1 images");

		getBCB().addBro(RSBro.getParam(), RSBro);
		
		lesBro = new Browser(frame, "[Optional]Lesions directory :", 
				BCBEnum.fType.DIR.a(), conf, BCBEnum.Param.RLESDIR, getBCB());
		getBCB().addBro(lesBro.getParam(), lesBro);
		
		resBro = new Browser(frame, "Results directory :", 
				BCBEnum.fType.DIR.a(), conf, BCBEnum.Param.RRESDIR, getBCB());
		getBCB().addBro(resBro.getParam(), resBro);
		
		String[] tab = {"", "None", "Regular up", "Regular down", "Interleaved"};
		sliceCombo = new JComboBox<String>(tab);
		
		saveTmp = new JCheckBox("Keep temporary files");
		saveTmp.setPreferredSize(new Dimension(260, 20));
		saveTmp.setIconTextGap(20);
		saveTmp.setSelected(conf.getVal(BCBEnum.Param.CSAVETMP).equals("true"));
		saveTmp.setMargin(new Insets(0, 0, 0, 0));
	}

	protected void placeComponents() {	
		JPanel sliceSelector = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
			JPanel comboPanel = new JPanel(new GridLayout(2, 0)); {
				comboPanel.add(new JLabel("Select slice timing correction :"));
				comboPanel.add(sliceCombo);
			}
			sliceSelector.add(comboPanel);
		}
		JPanel center = new JPanel(new GridLayout(4, 0)); {
			center.add(T1Bro);
			center.add(RSBro);
			center.add(lesBro);
			center.add(resBro);
		}
		JPanel centerBig = new JPanel(new BorderLayout()); {
			centerBig.add(center, BorderLayout.NORTH);
			centerBig.add(sliceSelector, BorderLayout.SOUTH);			
		}
		frame.add(background, BorderLayout.NORTH);
		frame.add(centerBig, BorderLayout.CENTER);
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

		settings.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				getBCB().openSettings(BCBEnum.Index.RESTING);
			}
		});

		run.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				worker = new SwingWorker<Void, Void>() {
					@Override
					public Void doInBackground() {
						if (Tools.isReady(frame, T1Bro)) {
							model.setT1Dir(T1Bro.getPath());
						} else {
							return null;
						}
						if (Tools.isReady(frame, RSBro)) {
							model.setRSDir(RSBro.getPath());
						} else {
							return null;
						}
						
						//This path could be empty if you don't want to mask lesions
						model.setLesionDir(lesBro.getPath());
						
						if (Tools.isReady(frame, resBro)) {
							model.setResultDir(resBro.getPath());
						} else {
							return null;
						}
						
						// Should we save temporary files
						if (saveTmp.isSelected()) {
							model.setSaveTmp("true");
						} else {
							model.setSaveTmp("false");
						}
						
						String sliceValue = (String)sliceCombo.getSelectedItem();
						if (sliceValue.equals("")) {
							Tools.showErrorMessage(frame, "You have to chose the right slice"
									+ " timing correction among : "
									+ " : None"
									+ " : Regular up (0, 1, 2, 3, ...)"
									+ " : Regular down"
									+ " : Interleaved (0, 2, 4 ... 1, 3, 5 ... )");
						} else {
							model.setSliceTiming(sliceValue);
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
		
		saveTmp.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				if (saveTmp.isSelected()) {
					conf.setVal(BCBEnum.Param.RSAVETMP, "true");
				} else {
					conf.setVal(BCBEnum.Param.RSAVETMP, "false");
				}
			}
		});
	}

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
	
	@Override
	public void cancel() {
		if (worker != null) {
			Tools.cancelActions(path + "/Tools/tmp/tmpResting", worker);
		}
	}
	
	@Override
	public void stopProcess() {
		model.stopProcess();
	}
}

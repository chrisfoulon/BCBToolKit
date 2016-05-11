package Applications;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.net.URL;

import javax.swing.Icon;
import javax.swing.ImageIcon;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTextField;
import javax.swing.SwingConstants;
import javax.swing.SwingWorker;

import Config.BCBEnum;
import IHM.BCBToolKit;
import IHM.BCBToolKitIHM;
import IHM.Browser;
import IHM.ImagePanel;
import IHM.LoadingBar;
import IHM.Tools;
import Models.DiscoModel;

public class Disco extends AbstractApp {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 390;
	// Ecart entre l'icone et les bordure des boutons. 
	public static final int ICON_PADDING = 4;
	public static final int INFRAME_PADDING = 20;
	public static final int LINE_HEIGHT = 20;
	public static final String HYPER_TITLE = "Disconnectome maps";
	public static final String DEF_LES = "/Lesions";
	private ImagePanel background;
	private JPanel panel;
	private JButton settings;
	private JButton run;
	private LoadingBar loading;
	private DiscoModel model;
	//Threshold option
	private JTextField thrOpt;

	//Browsers
	private Browser lesBro;
	private Browser resBro;

	public Disco(String path, BCBToolKitIHM b) {
		super(path, b, BCBEnum.Index.DISCONNECTOME);
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

	protected void createModel() {
		model = new DiscoModel(path, this.getFrame());
	}

	protected void createView() {
		//Frame
		frame = new JFrame(HYPER_TITLE); {
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setResizable(false);
			display();
			frame.setFocusable(true);
		}
		background = new ImagePanel("disco.png", 140, 112);
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
		lesBro = new Browser(frame, "Lesions directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.DLESDIR, getBCB());
		lesBro.setDefPath(path + getDefaultLesions());
		lesBro.firstReset();

		getBCB().addBro(lesBro.getParam(), lesBro);
		
		resBro = new Browser(frame, "Results directory :", 
				BCBEnum.fType.DIR.a(), conf, BCBEnum.Param.DRESDIR, getBCB());
		getBCB().addBro(resBro.getParam(), resBro);

		thrOpt = new JTextField("0.0");
		thrOpt.setPreferredSize(new Dimension(50, 20));
		thrOpt.setToolTipText("<html> Increasing your % threshold of your disconnectome"
				+ "<br /> maps increase intersubjects reliability"
				+ "<br /> we recommend using 0.5 for AnaCOM2");
	}

	protected void placeComponents() {
		JPanel t = new JPanel(new BorderLayout()); {
			JLabel lab = new JLabel("Threshold (0.0 to 1.0) :");
			lab.setHorizontalAlignment(SwingConstants.CENTER);
			t.add(lab, BorderLayout.CENTER);
			JPanel t1 = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
				t1.add(thrOpt);
			}
			t.add(t1, BorderLayout.SOUTH);
			t.setMaximumSize(new Dimension(BCBToolKit.FRAME_WIDTH - 10, 45));
		}		
		
		JPanel center = new JPanel(new GridLayout(3, 0)); {
			center.add(lesBro);
			center.add(resBro);
			center.add(t);
		}
		frame.add(background, BorderLayout.NORTH);
		frame.add(center, BorderLayout.CENTER);
		// Panel contenant la checkBox
		JPanel r1 = new JPanel(new FlowLayout(FlowLayout.RIGHT)); {
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
				getBCB().openSettings(BCBEnum.Index.DISCONNECTOME);
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
						if (Tools.isReady(frame, resBro)) {
							model.setResultDir(resBro.getPath());
						} else {
							return null;
						}
						
						String text = thrOpt.getText();
						//Deleting of invisible characters
						text = text.trim();
						//Replace , by .
						text = text.replace(",", ".");
						if (!text.equals("0.0")) {
							float opt = 1.0f;
							try {
								opt = Float.valueOf(text);
							} catch (NumberFormatException nbE) {
								Tools.showErrorMessage(getBCB().getFrame(), 
										"Threshold have to be between 0.0 and 1.0");
								thrOpt.setText("0.0");
								return null;
							}
							if (opt < 0.0f || opt > 1.0f) {
								Tools.showErrorMessage(getBCB().getFrame(), 
										"Threshold have to be between 0.0 and 1.0");
								thrOpt.setText("0.0");
								return null;
							}
						}
						model.setThrOpt(text);
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

	//Return the default lesion path.
	private String getDefaultLesions() {
		return DEF_LES;
	}
	
	@Override
	public void cancel() {
		if (worker != null) {
			Tools.cancelActions(path + "/Tools/tmp/tmpHyp", worker);
		}
	}
	
	@Override
	public void stopProcess() {
		model.stopProcess();
	}
}

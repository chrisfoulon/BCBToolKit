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
import javax.swing.JPanel;
import javax.swing.SwingWorker;

import Config.BCBEnum;
import IHM.BCBToolKitIHM;
import IHM.Browser;
import IHM.ImagePanel;
import IHM.LoadingBar;
import IHM.Tools;
import Models.DiscoModel;

public class Resting extends AbstractApp {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 390;
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
	private DiscoModel model;

	//Browsers
	private Browser T1Bro;
	private Browser RSBro;
	private Browser resBro;

	public Resting(String path, BCBToolKitIHM b) {
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
		frame = new JFrame(RESTING_TITLE); {
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
		T1Bro = new Browser(frame, "Lesions directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.DLESDIR, getBCB());
		T1Bro.firstReset();
		
		RSBro = new Browser(frame, "Lesions directory :", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.DLESDIR, getBCB());
		RSBro.firstReset();

		getBCB().addBro(T1Bro.getParam(), T1Bro);
		
		resBro = new Browser(frame, "Results directory :", 
				BCBEnum.fType.DIR.a(), conf, BCBEnum.Param.DRESDIR, getBCB());
		getBCB().addBro(resBro.getParam(), resBro);
	}

	protected void placeComponents() {		
		JPanel center = new JPanel(new GridLayout(3, 0)); {
			center.add(T1Bro);
			center.add(resBro);
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
						if (Tools.isReady(frame, T1Bro)) {
							model.setLesionDir(T1Bro.getPath());
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
			Tools.cancelActions(path + "/Tools/tmp/tmpHyp", worker);
		}
	}
	
	@Override
	public void stopProcess() {
		model.stopProcess();
	}
}

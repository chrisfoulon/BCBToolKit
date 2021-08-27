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
import Models.StatisticalModel;

public class Statistical extends AbstractApp {
	//ATTRIBUTS
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 410;
	// Ecart entre l'icone et les bordure des boutons. 
	public static final int ICON_PADDING = 4;
	public static final int INFRAME_PADDING = 20;
	public static final int LINE_HEIGHT = 20;
	public static final String HYPER_TITLE = "Statistical Analysis";
	private ImagePanel background;
	private JPanel panel;
	private JPanel topP;
	private JButton settings;
	private JButton run;
	private LoadingBar loading;
	private StatisticalModel model;

	//Browsers
	private Browser map1Bro;
	private Browser map2Bro;
	private Browser resBro;

	public Statistical(String path, BCBToolKitIHM b) {
		super(path, b, BCBEnum.Index.STATISTICAL);
	}

	//COMMANDES
	protected void createModel() {
		model = new StatisticalModel(path, this.getFrame());
	}

	protected void createView() {
		//Frame
		frame = new JFrame(HYPER_TITLE); {
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT));
			frame.setResizable(false);
			display();
			frame.setFocusable(true);
		}
		background = new ImagePanel("LogoT.png");
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

	protected void placeComponents() {			
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

	protected void createControllers() {
		Tools.gatherRound(this);
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
		//TODO
		return; 
	}
}

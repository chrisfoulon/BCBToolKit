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
import javax.swing.JCheckBox;
import javax.swing.JComboBox;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTextField;
import javax.swing.SwingWorker;

import Config.BCBEnum;
import IHM.BCBToolKitIHM;
import IHM.Browser;
import IHM.ImagePanel;
import IHM.Tools;
import Models.AnacomModel;

public class Anacom extends AbstractApp {
	public static final String ANACOM_TITLE = "AnaCOM";
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 460;

	private ImagePanel background;
	private JPanel panel;
	private JPanel topP;
	private JButton settings;
	private JButton run;
	
	private JComboBox<String> testCombo;
	private Browser lesBro;
	private Browser resBro;
	private Browser csvBro;
	private JTextField threshFld;
	private JCheckBox saveTmp;
	
	private AnacomModel model;

	public Anacom(String path, BCBToolKitIHM b) {
		super(path, b, BCBEnum.Index.ANACOM);
	}

	protected void createModel() {
		model = new AnacomModel(this.getPath(), this.getFrame());
	}

	protected void createView() {
		//Frame
		frame = new JFrame(ANACOM_TITLE); {
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
		
		
		String[] tab = {"Option 1", "Option 2", "Option 3", "Option 4"};
		testCombo = new JComboBox<String>(tab);
		lesBro = new Browser(this.getFrame(), "Lesions directory :", BCBEnum.fType.DIR.a(),
				this.getConf(), BCBEnum.Param.ALESDIR, this.getBCB());
		resBro = new Browser(this.getFrame(), "Result directory :", BCBEnum.fType.DIR.a(),
				this.getConf(), BCBEnum.Param.ARESDIR, this.getBCB());
		csvBro = new Browser(this.getFrame(), "Patient names / scores (.csv file) :", BCBEnum.fType.CSV.a(),
				this.getConf(), BCBEnum.Param.ALESDIR, this.getBCB());
		saveTmp = new JCheckBox("Keep temporary files");
		saveTmp.setPreferredSize(new Dimension(260, 20));
		saveTmp.setIconTextGap(20);
		saveTmp.setSelected(conf.getVal(BCBEnum.Param.ASAVETMP).equals("true"));
		String thresh = conf.getVal(BCBEnum.Param.ATHRESH);
		if (thresh.equals("")) {
			thresh = "3";
		}
		threshFld = new JTextField(thresh);
		threshFld.setHorizontalAlignment(JTextField.RIGHT);
		threshFld.setPreferredSize(new Dimension(40, LINE_HEIGHT));
	}

	protected void placeComponents() {
		
		JPanel testSelector = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
			testSelector.add(testCombo);
		}
		
		JPanel center = new JPanel(new GridLayout(3, 0)); {
			center.add(lesBro);
			center.add(resBro);
			center.add(csvBro);
		}
		topP = new JPanel(new FlowLayout(FlowLayout.CENTER));
		topP.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT));
		frame.add(topP);
		frame.add(background, BorderLayout.NORTH);

		JPanel thr = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
			JLabel l = new JLabel("Cluster threshold : ");
			thr.add(l);
			thr.add(threshFld);
		}
		// A box layout could be more logical but ... it works
		JPanel grid = new JPanel(new BorderLayout()); {
			grid.add(testSelector, BorderLayout.NORTH);
			grid.add(center, BorderLayout.CENTER);
			grid.add(thr, BorderLayout.SOUTH);
			
		}
		frame.add(grid, BorderLayout.CENTER);
		// Panel contenant les deux checkbox
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
		
		run.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				worker = new SwingWorker<Void, Void>() {
					@Override
					public Void doInBackground() {
						// We test if the string is an integer
						try {
						    Integer.parseInt(threshFld.getText());
						} catch (NumberFormatException e) {
							Tools.showErrorMessage(frame, "The threshold must be an integer");
						    return null;
						}
						model.setThreshold(threshFld.getText());
						// We have to remove empty lines at the end of the csv file to 
						// avoid errors in the script.
						File tmpdir = new File(getBCB().getWD() + "/Tools/tmp/tmpAnacom");
						System.out.println(tmpdir.getAbsolutePath());
						boolean b = tmpdir.mkdirs();
						if (b == false) {
							System.out.println("ERROR : impossible to create the anacom tmp dir");
							return null;
						}
						String copypath = new String(getBCB().getWD() + "/Tools/tmp/tmpAnacom/tmpcsv.csv");
						Tools.removeEmptyLines(csvBro.getFldContent(), copypath);
						model.setCSV(copypath);
						
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

	protected void changeRunButton(JPanel p, int state) {
		
	}
}

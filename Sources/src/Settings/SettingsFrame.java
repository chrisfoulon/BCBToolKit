package Settings;

import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.FocusEvent;
import java.awt.event.FocusListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.util.HashMap;

import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTabbedPane;
import javax.swing.JTextField;
import javax.swing.SwingConstants;

import Applications.Tractotron;
import Config.BCBEnum;
import Config.BCBEnum.Param;
import Config.Config;
import IHM.BCBToolKit;
import IHM.BCBToolKitIHM;
import IHM.Browser;
import IHM.Tools;

public class SettingsFrame implements Settings {

	public static final int LBL_PADDING = 60;
	private JDialog dialog;
	private Config conf;
	private BCBToolKitIHM bcb;
	private String startDir;
	// Components
	private JButton okBut;
	//private JButton applyBut;
	//private JButton cancelBut;

	//Tabs :
	//Component which will receive tabs
	private JTabbedPane tabs;
	//General
	private JCheckBox startCheck;
	private Browser startBro;
	private JCheckBox saveDir;
	private JCheckBox saveLoc;
	//Normalisation
	//private JTextField betOpt;
	private JTextField gradientStepFld;
	private JTextField updateFieldVarianceInVoxelSpaceFld;
	private JTextField totalFieldVarianceInVoxelSpaceFld;
	private String gradientStep;
	private String updateFieldVarianceInVoxelSpace;
	private String totalFieldVarianceInVoxelSpace;
	//Anacom
	private JTextField nbVox;

	private HashMap<BCBEnum.Param, JButton> butMap;

	private HashMap<BCBEnum.Param, String> pathsMap;

	public SettingsFrame(Config c, BCBToolKitIHM bcb) {
		super();
		if (c == null) {
			throw new IllegalArgumentException("Conf is null");
		}
		if (bcb == null) {
			throw new IllegalArgumentException("The BCBToolBoxIHM is null");
		}
		this.bcb = bcb;
		this.conf = c;
		this.pathsMap = new HashMap<BCBEnum.Param, String>(bcb.getPathsMap());
		String tmp = c.getVal(BCBEnum.Param.NGRADIENTSTEP);
		if (tmp.equals("")) {
			gradientStep = "0.1";
		} else {
			gradientStep = tmp;
		}
		
		tmp = c.getVal(BCBEnum.Param.NUPDATEFIELDVARIANCE);
		if (tmp.equals("")) {
			updateFieldVarianceInVoxelSpace = "3.0";
		} else {
			updateFieldVarianceInVoxelSpace = tmp;
		}
		
		tmp = c.getVal(BCBEnum.Param.NTOTALFIELDVARIANCE);
		if (tmp.equals("")) {
			totalFieldVarianceInVoxelSpace = "0.0";
		} else {
			totalFieldVarianceInVoxelSpace = tmp;
		}

		createView();
		placeComponents();
		createController();
	}


	// PARTIE IHM
	private void createView() {
		dialog = new JDialog(this.getBCB().getFrame(), "Settings");
		dialog.setResizable(false);
		dialog.setPreferredSize(new Dimension(
				BCBToolKitIHM.FRAME_WIDTH - BCBToolKitIHM.INFRAME_PADDING,
				BCBToolKitIHM.FRAME_HEIGHT - BCBToolKitIHM.INFRAME_PADDING));
		dialog.pack();
		dialog.setLocationRelativeTo(this.getBCB().getFrame());

		okBut = new JButton("Ok");
		//applyBut = new JButton("Apply");
		//cancelBut = new JButton("Cancel");

		createButtons();

		//General
		startCheck = new JCheckBox();
		startCheck.setToolTipText("Define the starting directory of browsers");
		startBro = new Browser(this.getBCB().getFrame(), "Set Path :         ", BCBEnum.fType.DIR.a(), 
				conf, BCBEnum.Param.STARTDIR,
				Tractotron.FRAME_WIDTH - LBL_PADDING, null);
		startBro.setDefPath(System.getProperty("user.home"));
		saveDir = new JCheckBox("Save directories after shutdown");
		// Modify the gap between check and text
		saveDir.setIconTextGap(20);
		saveLoc = new JCheckBox("Save the location of frames");
		saveLoc.setSelected(false);
		saveLoc.setIconTextGap(20);
				
		//betOpt = new JTextField();
		//betOpt.setPreferredSize(new Dimension(50, 20));
		
		// AntsReg SyN parameters
		// GradientStep
		gradientStepFld = new JTextField(gradientStep);
		gradientStepFld.setPreferredSize(new Dimension(45, 20));
		gradientStepFld.setToolTipText("<html> gradientStep - tells the algorithm how much each point can "
				+ "<br />move after each iteration. The SyN metric computes in which "
				+ "<br />direction each point needs to move. This movement can be large "
				+ "<br />(high gradientStep) or small (low gradientStep). Optimal values 0.1-0.25. "
				+ "<br />Because the shift of each point is computed separately, high values "
				+ "<br />here may also increase high frequency deformations "
				+ "<br />(i.e., each point going its own way), but see the other parameters "
				+ "<br />below that mitigate this problem.</html>");
		// updateFieldVarianceInVoxelSpace
		updateFieldVarianceInVoxelSpaceFld = new JTextField(updateFieldVarianceInVoxelSpace);
		updateFieldVarianceInVoxelSpaceFld.setPreferredSize(new Dimension(45, 20));
		updateFieldVarianceInVoxelSpaceFld.setToolTipText("<html> After each iteration, a gradient field is computed, "
				+ "<br />which indicates how each point (or voxel) will shift in space. "
				+ "<br />This small deformation (or \"updated\" gradient field) is combined"
				+ "<br /> with previous updates to form a \"total\" gradient deformation. "
				+ "<br />Because each point can follow its own path, non-realistic deformations"
				+ "<br /> can occur, which may make images look like teared apart. "
				+ "<br />To resolve this issue we add a little penalty, such that shifts "
				+ "<br />are not considered independently at each point.\n" + 
				"<br />updateFieldVarianceInVoxelSpace - By adding a penalty here, we smooth the "
				+ "<br />deformation computed on the \"updated\" gradient field, before "
				+ "<br />this is added to previous deformations to form the \"total\" gradient field. "
				+ "<br />Thus, for each point the deformation of neighboring points is taken into "
				+ "<br />account as well, which avoids too much independent moving of points at "
				+ "<br />each iteration (i.e., a point cannot move 2 voxels away in one direction "
				+ "<br />if all it's neighbors are moving 0.1 voxels away in the other direction).</html>");
		// totalFieldVarianceInVoxelSpace
		totalFieldVarianceInVoxelSpaceFld = new JTextField(totalFieldVarianceInVoxelSpace);
		totalFieldVarianceInVoxelSpaceFld.setPreferredSize(new Dimension(45, 20));
		totalFieldVarianceInVoxelSpaceFld.setToolTipText("<html> totalFieldVarianceInVoxelSpace - By adding a penalty "
				+ "<br />here, we smooth the deformation computed on the \"total\" gradient field. "
				+ "<br />The smoothing here, therefore, is applied on all the deformations "
				+ "<br />computed from the beginning (i.e., at this and all previous SyN iterations)." + 
				"<br />In principle, smoothing of the update field can be viewed as fluid-like "
				+ "<br />registration whereas smoothing of the total field can be viewed as "
				+ "<br />elastic registration. </html>");
		// Anacom
		String nbvox_str = conf.getVal(Param.AVOXNB);
		if (nbvox_str.equals("")) {
			nbVox = new JTextField("512");
		} else {
			nbVox = new JTextField(nbvox_str);
		}
		
		nbVox.setPreferredSize(new Dimension(50, 20));
		//LoadSettings
		loadSettings();
	}

	private void placeComponents() {
		this.tabs = new JTabbedPane(SwingConstants.TOP);

		JPanel generalTab = new JPanel(); {
			BoxLayout boxLay = new BoxLayout(generalTab, BoxLayout.Y_AXIS);
			generalTab.setLayout(boxLay);
			JPanel p = new JPanel(new FlowLayout(FlowLayout.LEFT)); {
				JPanel p1 = new JPanel(new GridLayout(2, 0)); {
					JPanel j = new JPanel();
					j.setPreferredSize(new Dimension(25, 25));
					p1.add(j);
					p1.add(startCheck);
				}
				p.add(p1);
				p.add(startBro);
			}
			p.setMaximumSize(new Dimension(BCBToolKitIHM.FRAME_WIDTH, BCBToolKitIHM.LINE_HEIGHT * 4));
			generalTab.add(p);
			JPanel r = new JPanel(new FlowLayout(FlowLayout.LEFT)); {
				r.add(saveDir);
			}
			r.setMaximumSize(new Dimension(BCBToolKitIHM.FRAME_WIDTH, 25));
			//r.setBorder(BorderFactory.createLineBorder(Color.black));
			generalTab.add(r);
			JPanel s = new JPanel(new FlowLayout(FlowLayout.LEFT)); {
				s.add(saveLoc);
			}
			s.setMaximumSize(new Dimension(BCBToolKitIHM.FRAME_WIDTH, 25));
			generalTab.add(s);
		}

		JPanel tractoTab = new JPanel(); {
			BoxLayout boxLay1 = new BoxLayout(tractoTab, BoxLayout.Y_AXIS);
			tractoTab.setLayout(boxLay1);
			//tractoOnglet.setPreferredSize(new Dimension(300, 80));
			tractoTab.add(butMap.get(BCBEnum.Param.TLESDIR));
			tractoTab.add(butMap.get(BCBEnum.Param.TTRADIR));
			tractoTab.add(butMap.get(BCBEnum.Param.TRESDIR));
		}
		JPanel discoTab = new JPanel(); {
			BoxLayout boxLay2 = new BoxLayout(discoTab, BoxLayout.Y_AXIS);
			discoTab.setLayout(boxLay2);
		}

		JPanel cortiTab = new JPanel(); {
			BoxLayout boxLay3 = new BoxLayout(cortiTab, BoxLayout.Y_AXIS);
			cortiTab.setLayout(boxLay3);
		}

		JPanel normaTab  = new JPanel(); {
			BoxLayout boxLay4 = new BoxLayout(normaTab, BoxLayout.Y_AXIS);
			normaTab.setLayout(boxLay4);
			normaTab.add(butMap.get(BCBEnum.Param.NTEMPDIR));
			normaTab.add(Box.createRigidArea(new Dimension(0, 0)));
			/*JPanel p = new JPanel(new BorderLayout()); {
				JLabel lab = new JLabel("Brain extraction Threshold (0.0 to 1.0) :");
				lab.setHorizontalAlignment(SwingConstants.CENTER);
				p.add(lab, BorderLayout.CENTER);
				JPanel p1 = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
					p1.add(betOpt);
				}
				p.add(p1, BorderLayout.SOUTH);
				p.setMaximumSize(new Dimension(BCBToolKit.FRAME_WIDTH - 10, 45));
			}*/

			JPanel t = new JPanel(new FlowLayout(FlowLayout.LEFT)); {
				JPanel p1 = new JPanel(new GridLayout(7, 0, 0, -5)); {
					JLabel lab = new JLabel("Syn parameters:");
					lab.setHorizontalAlignment(SwingConstants.LEFT);
					JLabel grad_lab = new JLabel("gradientStep");
					grad_lab.setHorizontalAlignment(SwingConstants.LEFT);
					JLabel update_lab = new JLabel("updateFieldVarianceInVoxelSpace");
					update_lab.setHorizontalAlignment(SwingConstants.LEFT);
					JLabel total_lab = new JLabel("totalFieldVarianceInVoxelSpace");
					total_lab.setHorizontalAlignment(SwingConstants.LEFT);
					p1.add(lab);
					p1.add(grad_lab);
					JPanel t1 = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
						t1.add(gradientStepFld);
					}
					p1.add(t1);
					p1.add(update_lab);
					JPanel t2 = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
						t2.add(updateFieldVarianceInVoxelSpaceFld);
					}
					p1.add(t2);
					p1.add(total_lab);
					JPanel t3 = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
						t3.add(totalFieldVarianceInVoxelSpaceFld);
					}
					p1.add(t3);
				}
				t.add(p1);
				t.setMaximumSize(new Dimension(BCBToolKit.FRAME_WIDTH - 10, 100));
			}
			//normaTab.add(p);
			normaTab.add(t);
			/*It's useless ... I made a mistake.
			normaTab.add(new Renamer("T1", "Add / Remove T1 prefix :", 
					getBCB().getFrame(), getBCB()));
			normaTab.add(new Renamer("LES", "Add / Remove LES prefix :", 
					getBCB().getFrame(), getBCB()));
			normaTab.add(new Renamer("OTH", "Add / Remove OTH prefix :", 
					getBCB().getFrame(), getBCB()));*/
		}

		JPanel anacomTab = new JPanel(); {
			BoxLayout boxLay5 = new BoxLayout(anacomTab, BoxLayout.Y_AXIS);
			anacomTab.setLayout(boxLay5);
			JPanel p = new JPanel(new BorderLayout()); {
				JLabel lab = new JLabel("Minimum number of voxels for clusters :");
				lab.setHorizontalAlignment(SwingConstants.CENTER);
				p.add(lab, BorderLayout.CENTER);
				JPanel p1 = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
					p1.add(nbVox);
				}
				p.add(p1, BorderLayout.SOUTH);
				p.setMaximumSize(new Dimension(BCBToolKit.FRAME_WIDTH - 10, 45));
			}
			anacomTab.add(p);
		}

		JPanel funconTab = new JPanel(); {
			BoxLayout boxLay3 = new BoxLayout(funconTab, BoxLayout.Y_AXIS);
			funconTab.setLayout(boxLay3);
			funconTab.add(butMap.get(BCBEnum.Param.FTARDIR));
			//statTab.add(butMap.get(BCBEnum.Param.SMAP1DIR));
			//statTab.add(butMap.get(BCBEnum.Param.SMAP2DIR));
			//statTab.add(butMap.get(BCBEnum.Param.SRESDIR));
		}

		JPanel bottom = new JPanel(new FlowLayout(FlowLayout.RIGHT)); {
			bottom.add(okBut);
			//bottom.add(applyBut);
			//bottom.add(cancelBut);
		}

		tabs.addTab("General", generalTab);
		tabs.addTab("Tractotron", tractoTab);
		tabs.addTab("Disconnectome maps", discoTab);
		tabs.addTab("Cortical thickness", cortiTab);
		tabs.addTab("Normalisation", normaTab);
		tabs.addTab("anaCOM2", anacomTab);
		tabs.addTab("Funcon", funconTab);
		tabs.setOpaque(true);

		dialog.add(tabs, BorderLayout.CENTER);
		dialog.add(bottom, BorderLayout.SOUTH);
	}

	private void createController() {
		dialog.addWindowListener(new WindowAdapter() {
			public void windowClosing(WindowEvent we) {
				applyChanges();
				closeSettings();
			}
		});
		startCheck.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				if (startCheck.isSelected()) {
					startBro.activate();
				} else {
					startBro.deactivate();
				}
			}
		});

		saveDir.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				if (saveDir.isSelected()) {
					getBCB().savePaths(true);
				} else {
					getBCB().savePaths(false);
				}
			}
		});

		/*betOpt.addFocusListener(new FocusListener() {

			@Override
			public void focusLost(FocusEvent e) {
				String text = betOpt.getText();
				//Deleting of invisible characters
				text = text.trim();
				//Replace , by .
				text = text.replace(",", ".");
				if (!text.equals("")) {
					float opt = 0;
					try {
						opt = Float.valueOf(text);
					} catch (NumberFormatException nbE) {
						Tools.showErrorMessage(getBCB().getFrame(), 
								"The value of Brain extraction threshold" +
								" be between 0.0 and 1.0");
						betOpt.setText("");
						conf.setVal(BCBEnum.Param.NBETOPT, "");
						return;
					}
					if (!(opt < 0) && !(opt > 1)) {
						conf.setVal(BCBEnum.Param.NBETOPT, text);
					} else {
						Tools.showErrorMessage(getBCB().getFrame(), 
								"The value of Brain extraction threshold" +
								" be between 0.0 and 1.0");
						betOpt.setText("");
						conf.setVal(BCBEnum.Param.NBETOPT, "");
						return;
					}
				}
			}

			@Override
			public void focusGained(FocusEvent e) {
			}
		});*/
		
		gradientStepFld.addFocusListener(new FocusListener() {

			@Override
			public void focusLost(FocusEvent e) {
				gradientStep = checkFloatTextField(
						gradientStepFld.getText(), 
						"0.1", 
						"gradientStep takes a number");
				gradientStepFld.setText(gradientStep);
			}

			@Override
			public void focusGained(FocusEvent e) {
			}
		});
		
		updateFieldVarianceInVoxelSpaceFld.addFocusListener(new FocusListener() {

			@Override
			public void focusLost(FocusEvent e) {
				updateFieldVarianceInVoxelSpace = checkFloatTextField(
						updateFieldVarianceInVoxelSpaceFld.getText(), 
						"3.0", 
						"updateFieldVarianceInVoxelSpace takes a number");
				updateFieldVarianceInVoxelSpaceFld.setText(updateFieldVarianceInVoxelSpace);
			}

			@Override
			public void focusGained(FocusEvent e) {
			}
		});
		
		totalFieldVarianceInVoxelSpaceFld.addFocusListener(new FocusListener() {

			@Override
			public void focusLost(FocusEvent e) {
				totalFieldVarianceInVoxelSpace = checkFloatTextField(
						totalFieldVarianceInVoxelSpaceFld.getText(), 
						"0.0", 
						"totalFieldVarianceInVoxelSpace takes a number");
				totalFieldVarianceInVoxelSpaceFld.setText(totalFieldVarianceInVoxelSpace);
			}

			@Override
			public void focusGained(FocusEvent e) {
			}
		});

		nbVox.addFocusListener(new FocusListener() {

			@Override
			public void focusLost(FocusEvent e) {
				String text = nbVox.getText();
				//Deleting of invisible characters
				text = text.trim();
				try {
					Integer.parseInt(text);
				} catch (NumberFormatException n) {
					Tools.showErrorMessage(getBCB().getFrame(), 
							"The number of voxels must be an integer >= 0");
					nbVox.setText("512");
					return;
				}
			}

			@Override
			public void focusGained(FocusEvent e) {
			}
		});

		updateResetControllers();

		okBut.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				applyChanges();
				closeSettings();
			}
		});
	}

	/**
	 * Create reset buttons
	 */
	private void createButtons() {
		butMap = new HashMap<BCBEnum.Param, JButton>(); 
		for (BCBEnum.Param p : pathsMap.keySet()) {
			String[] tmp = p.key().split("\\ ");
			Dimension dim = new Dimension(Tractotron.FRAME_WIDTH, Tractotron.LINE_HEIGHT);
			JButton but = new JButton("Reset " + 
					tmp[tmp.length - 1] + " path");
			but.setAlignmentX(Component.CENTER_ALIGNMENT);
			but.setMaximumSize(dim);
			butMap.put(p, but);
		}
	}
	
	private String checkFloatTextField(String in, String defVal, String errorMsg) {
		/*
		 * If the string can be parsed as a float, return it otherwise, 
		 * return the default value
		 */
		//Deleting of invisible characters
		String text = in.trim();
		//Replace , by .
		text = text.replace(",", ".");
		if (!text.equals(defVal)) {
			try {
				Float.parseFloat(text);
			} catch (NumberFormatException nbE) {
				Tools.showErrorMessage(getBCB().getFrame(), errorMsg);
				return defVal;
			}
			return text;
		} else {
			return defVal;
		}
	}

	public void updateResetControllers() {
		for (BCBEnum.Param p : butMap.keySet()) {
			butMap.get(p).addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					if (getBCB().getBroMap().get(p) != null) {
						getBCB().resetBro(p);
					}
				}
			});
		}
	}

	public boolean saveLocations() {
		return saveLoc.isSelected();
	}

	private void loadSettings() {
		// We set the good state of the checkBox startCheck
		if (!conf.getVal(BCBEnum.Param.STARTDIR).equals("")) {
			startCheck.setSelected(true);
			startBro.activate();
		} else {
			startCheck.setSelected(false);
			startBro.deactivate();
		}
		// We set the good state of the checkBox saveDir
		if (conf.getVal(BCBEnum.Param.SAVE_PATHS).equals("true")) {
			saveDir.setSelected(true);
		} else {
			saveDir.setSelected(false);
		}
		for (BCBEnum.Index i : BCBEnum.Index.values()) {
			if (!conf.getVal(i.name()).equals("")) {
				saveLoc.setSelected(true);
			}
		}
	}

	/**
	 * Make the Dialog frame visible into the main frame (of the BCBToolBox)
	 */
	public void openSettings() {
		dialog.setLocationRelativeTo(getBCB().getFrame());
		dialog.setVisible(true);
	}

	/**
	 * Overload of openSettings adding the choice of the tab that will be open.
	 * @pre 
	 * 	!(index < 0 || index > tabs.getTabCount()) 
	 */
	public void openSettings(BCBEnum.Index index) {
		if (index.index() < 0 || index.index() > tabs.getTabCount()) {
			throw new IllegalArgumentException("There isn't tab indexed at " + index);
		}
		tabs.setSelectedIndex(index.index());
		openSettings();
	}

	public void closeSettings() {
		dialog.setVisible(false);
	}

	public String getNormSynParam() {
		String synParam = "[" + gradientStep + "," + updateFieldVarianceInVoxelSpace + "," +
		totalFieldVarianceInVoxelSpace + "]"; 
		return synParam;
	}
	
	public String getNbVox() {
		return nbVox.getText();
	}

	// Model 
	@Override
	public Config getConf() {
		return this.conf;
	}

	@Override
	public BCBToolKitIHM getBCB() {
		return this.bcb;
	}

	@Override
	public String getStartDir() { 
		return this.startDir;
	}

	@Override
	public void setStartDir(String start) {
		if (start == null) {
			throw new IllegalArgumentException("The start directory is null");
		}
		this.startDir = start;
	}

	@Override
	public void applyChanges() {
		conf.setVal(Param.AVOXNB, nbVox.getText());
		conf.setVal(BCBEnum.Param.NGRADIENTSTEP, gradientStep);
		conf.setVal(BCBEnum.Param.NUPDATEFIELDVARIANCE, updateFieldVarianceInVoxelSpace);
		conf.setVal(BCBEnum.Param.NTOTALFIELDVARIANCE, totalFieldVarianceInVoxelSpace);
		if (startCheck.isSelected()) {
			this.startBro.setConf();
		} else {
			conf.setVal(BCBEnum.Param.STARTDIR, "");
		}
		if (saveDir.isSelected()) {
			getBCB().savePaths(true);
			conf.setVal(BCBEnum.Param.SAVE_PATHS, "true");
		} else {
			getBCB().savePaths(false);
		}
	}
}

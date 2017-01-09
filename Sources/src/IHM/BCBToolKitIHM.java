package IHM;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.Font;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.awt.GridLayout;
import java.awt.Image;
import java.awt.Insets;
import java.awt.Point;
import java.awt.Rectangle;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.FocusEvent;
import java.awt.event.FocusListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URL;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;

import javax.swing.BorderFactory;
import javax.swing.Icon;
import javax.swing.ImageIcon;
import javax.swing.JButton;
import javax.swing.JComponent;
import javax.swing.JFrame;
import javax.swing.JMenu;
import javax.swing.JMenuBar;
import javax.swing.JMenuItem;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.SwingConstants;
import javax.swing.SwingUtilities;
import javax.swing.UIManager;
import javax.swing.UnsupportedLookAndFeelException;

import Applications.AbstractApp;
import Applications.Anacom;
import Applications.Cortical;
import Applications.Disco;
import Applications.Normalisation;
import Applications.Funcon;
import Applications.Statistical;
import Applications.Tractotron;
import Config.BCBEnum;
import Config.Config;
import Settings.SettingsFrame;

public class BCBToolKitIHM  implements BCBToolKit {	
	public static final int FRAME_HEIGHT = 350;
	private String wd;
	private JFrame frame;
	// MenuBar
	private JMenuBar menu;
	private JMenuItem settings;
	private JMenuItem ackno;
	private JMenuItem disclaimer;
	private JMenuItem about;
	// Appli buttons
	private JButton tracto;
	private JButton disco;
	private JButton corti;
	private JButton norma;
	private JButton anacom;
	private JButton funcon;
	//private JButton stat;
	//Set of buttons
	private HashSet<JButton> butSet;
	// Conf
	private SettingsFrame setFrame;
	private Config conf;
	// Determine if files will be saved after shutdown
	private boolean savePaths;
	// Applications
	
	// Map of positions of each frame, including BCBToolBox as GENERAL
	private Map<BCBEnum.Index, Point> posMap;
	/*
	 *  Maps of different paths/files that have to be saved and shared
	 *  There are loaded by the loadMaps function
	 */
	private Map<BCBEnum.Param, String> pathsMap;
	private Map<BCBEnum.Param, File> filesMap;
	/*
	 * A set to save all browser which will need to save their paths
	 * Updated by the function addBro each time an appli is opened 
	 */
	private HashMap<BCBEnum.Param, Browser> broMap;
	/*
	 * A map to store reference to each application
	 */
	private HashMap<BCBEnum.Index, AbstractApp> appMap;
	
	public BCBToolKitIHM(String wd) {
		this.wd = wd;
		this.conf = new Config(this.wd + "/Tools/extraFiles/BCBToolKit.conf");
		this.savePaths = conf.getVal(BCBEnum.Param.SAVE_PATHS).equals("true");
		// Creation of the button set
		this.butSet = new HashSet<JButton>();
		//Creation and initializing pathsMap and filesMap 
		this.pathsMap = new HashMap<BCBEnum.Param, String>();
		this.filesMap = new HashMap<BCBEnum.Param, File>();
		loadMaps();
		this.broMap = new HashMap<BCBEnum.Param, Browser>();
		this.posMap = new HashMap<BCBEnum.Index, Point>();
		this.appMap = new HashMap<BCBEnum.Index, AbstractApp>();
		
		createView();
		placeComponents();
		createControllers();
	}
	
	/**
	 * Loading file and path maps with checking of file 
	 * integrity
	 */
	private void loadMaps() {
		for (BCBEnum.Param p : BCBEnum.Param.values()) {
			if (p.key().startsWith("default")) {
				String tmp = conf.getVal(p);
				if (!tmp.equals("")) {
					File f = new File(tmp);
					if (!f.exists()) {
						Tools.showMessage(frame, "File issue warning", 
								"Warning : the " + p.key() + "doesn't exist");
						pathsMap.put(p, "");
						filesMap.put(p, null);
						conf.setVal(p, "");
					} else if (!f.canRead()) {
						Tools.showMessage(frame, "File issue warning", 
								"Warning : the " + p.key() + "is unreadable");
						pathsMap.put(p, "");
						filesMap.put(p, null);
						conf.setVal(p, "");
					} else if (!f.canWrite()) {
						Tools.showMessage(frame, "File issue warning", 
								"Warning : the " + p.key() + "cannot be open for writing");
						pathsMap.put(p, "");
						filesMap.put(p, null);
						conf.setVal(p, "");
					} else {
						filesMap.put(p, f);
						pathsMap.put(p, conf.getVal(p));
					}
				} else {
					pathsMap.put(p, "");
					filesMap.put(p, null);
				}
			}
		}
	}
	

	// IHM
	public void display() {
		frame.pack();
		if (conf.getVal(BCBEnum.Index.GENERAL.name()).equals("")) {
			GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
			GraphicsDevice defaultScreen = ge.getDefaultScreenDevice();
			Rectangle rect = defaultScreen.getDefaultConfiguration().getBounds();
			int x = (int)rect.getMaxX() / 8;
			int y = ((int)rect.getMaxY()-frame.getHeight()) / 2; //Milieu vertical
			frame.setLocation(x, y);
		} else {
			setCustomLocation(frame, BCBEnum.Index.GENERAL);
		}
		//frame.setLocationRelativeTo(null); //Met la frame au centre
		frame.setVisible(true);
	}
	
	public void createView() {
		frame = new JFrame("BCBToolKit"); {
			frame.setPreferredSize(new Dimension(FRAME_WIDTH, FRAME_HEIGHT + Tools.getOffset()));
			frame.setResizable(false);
			frame.setFocusable(true);
		}
		// Menu
		menu = new JMenuBar();
		settings = new JMenuItem("Settings");
		ackno = new JMenuItem("Acknowledgement");
		disclaimer = new JMenuItem("Dislaimer");
		about = new JMenuItem("About BCBToolKit");
		// Buttons
		
		tracto = textButton("Tractotron");
		disco = textButton("<html><center>Disconnectome<br />Maps<center/><html/>");
		corti = textButton("<html><center>Cortical<br />Thickness<center/><html/>");
		norma = textButton("Normalisation");
		anacom = textButton("AnaCOM2");
		funcon = textButton("Funcon");
		
		/*tracto = new JButton(buttonIcon("tracto.png", 150, 81));
		formatButton(tracto);
		disco = new JButton(buttonIcon("disco.png", 140, 120));
		formatButton(disco);
		corti = new JButton(buttonIcon("corti.png", 141, 93));
		formatButton(corti);
		norma = new JButton(buttonIcon("norma.png", 150, 120));
		formatButton(norma);
		URL url = getClass().getClassLoader().getResource("undercons.png");
		ImageIcon logo = new ImageIcon(url);
		anacom = new JButton(buttonIcon("anacomtxt.png", 120, 110));
		formatButton(anacom);
		stat = new JButton(Tools.twoLinesString("Statistical",  "Analysis"), logo);
		formatButton(stat);*/
		setFrame = new SettingsFrame(conf, this);
		// Once buttons created, we add them in the set
		butSet.add(tracto);
		butSet.add(disco);
		butSet.add(corti);
		butSet.add(norma);
		butSet.add(anacom);
		butSet.add(funcon);
		//butSet.add(stat);
		//stat.setEnabled(false);
	}
	
	public void placeComponents() {
		//Menus
		JMenu confMenu = new JMenu("Preferences"); {
			confMenu.add(settings);
		}
		JMenu help = new JMenu("Help"); {
			help.add(ackno);
			help.add(disclaimer);
			help.add(about);
		}
		menu.add(confMenu);
		menu.add(help);
		//Buttons
		JPanel p = new JPanel(); {
			GridLayout boxLay = new GridLayout(0, 2);
			p.setLayout(boxLay);
			p.add(tracto);
			p.add(disco);
			p.add(corti);
			p.add(norma);
			p.add(anacom);
			p.add(funcon);
			//p.add(stat);
		}
		p.setPreferredSize(new Dimension(FRAME_WIDTH - 10, 200));
		frame.setJMenuBar(menu);
		// On ajoute un logo en dessous de la barre de menu
		ImagePanel logo = new ImagePanel("BCBLogo.png", 152, 97);
		logo.setPreferredSize(new Dimension(FRAME_WIDTH, LINE_HEIGHT * 6));
		frame.add(logo , BorderLayout.NORTH);
		//frame.add(p, BorderLayout.CENTER);
		JPanel t = new JPanel(new FlowLayout(FlowLayout.LEADING));
		t.add(p);
		frame.add(t, BorderLayout.CENTER);
	}
	
	public void createControllers() {
		frame.setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);
		frame.addWindowListener(new WindowAdapter(){
			public void windowClosing(WindowEvent e) {
				int retour = Tools.showConfirmMessage(getFrame(), 
						"<html>If you close this window, all running modules will be shutdown"
						+ "<br /> Are you sure ? </html>");
				
				if(retour == JOptionPane.YES_OPTION){
					closing();
					System.exit(0);
				} else {
					return;
				}
			}
		});
		
		frame.addFocusListener(new FocusListener() {
			public void focusGained(FocusEvent e) {
				getBCB().allOnFront();
				getFrame().requestFocus();
			}

			public void focusLost(FocusEvent e) {
				return;
			}
		});
		
		settings.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				openSettings();
            }
		});
		
		tracto.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				callApp(BCBEnum.Index.TRACTOTRON);
            }
		});
		
		disco.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				callApp(BCBEnum.Index.DISCONNECTOME);
            }
		});
		
		corti.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				callApp(BCBEnum.Index.CORTICAL);
            }
		});
		
		norma.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				callApp(BCBEnum.Index.NORMALISATION);
            }
		});
		
		anacom.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				callApp(BCBEnum.Index.ANACOM);
            }
		});
		
		/*stat.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				callApp(BCBEnum.Index.STATISTICAL);
            }
		});*/

		funcon.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				callApp(BCBEnum.Index.FUNCON);
			}
		});
		
		disclaimer.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				File dis = new File(getWD() + "/DISCLAIMER");
				FileInputStream fis = null;
				try {
					fis = new FileInputStream(dis);
				} catch (FileNotFoundException e1) {
					e1.printStackTrace();
				}
				byte[] data = new byte[(int) dis.length()];
				try {
					fis.read(data);
					fis.close();
				} catch (IOException e2) {
					e2.printStackTrace();
				}

				String str = "";
				try {
					str = new String(data, "UTF-8");
				} catch (UnsupportedEncodingException e1) {
					e1.printStackTrace();
				}
				Tools.showLongMessage(frame, "DISCLAIMER", str);
            }
		});
		
		ackno.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				File dis = new File(getWD() + "/ACKNOWLEDGEMENT");
				FileInputStream fis = null;
				try {
					fis = new FileInputStream(dis);
				} catch (FileNotFoundException e1) {
					e1.printStackTrace();
				}
				byte[] data = new byte[(int) dis.length()];
				try {
					fis.read(data);
					fis.close();
				} catch (IOException e2) {
					e2.printStackTrace();
				}

				String str = "";
				try {
					str = new String(data, "UTF-8");
				} catch (UnsupportedEncodingException e1) {
					e1.printStackTrace();
				}
				Tools.showLongMessage(frame, "Acknowledgement", str);
            }
		});
		
		about.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				File dis = new File(getWD() + "/VERSION");
				FileInputStream fis = null;
				try {
					fis = new FileInputStream(dis);
				} catch (FileNotFoundException e1) {
					e1.printStackTrace();
				}
				byte[] data = new byte[(int) dis.length()];
				try {
					fis.read(data);
					fis.close();
				} catch (IOException e2) {
					e2.printStackTrace();
				}

				String str = "";
				try {
					str = new String(data, "UTF-8");
				} catch (UnsupportedEncodingException e1) {
					e1.printStackTrace();
				}
				Tools.showLongMessage(frame, "About BCBToolKit", str);
            }
		});
	}
	
	public BCBToolKitIHM getBCB() {
		return this;
	}
	
	public JFrame getFrame() {
		return this.frame;
	}
	
	public String getWD() {
		return this.wd;
	}
	
	public HashMap<BCBEnum.Param, String> getPathsMap() {
		HashMap<BCBEnum.Param, String> tmp = new HashMap<BCBEnum.Param, String>(this.pathsMap);
		return tmp;
	}
	
	public HashMap<BCBEnum.Param, File> getFilesMap() {
		HashMap<BCBEnum.Param, File> tmp = new HashMap<BCBEnum.Param, File>(this.filesMap);
		return tmp;
	}
	
	public String getPath(BCBEnum.Param p) {
		return pathsMap.get(p);
	}
	
	public File getFile(BCBEnum.Param p) {
		return filesMap.get(p);
	}
	
	public HashMap<BCBEnum.Param, Browser> getBroMap() {
		return new HashMap<BCBEnum.Param, Browser>(this.broMap);
	}
	
	private JButton textButton(String text) {
		JButton b = new JButton(text);
		b.setMaximumSize(new Dimension(150, 40));
		int style = Font.BOLD;
		b.setMargin(new Insets(1,1,1,1));
		b.setHorizontalAlignment(SwingConstants.CENTER);
		Font font = new Font("Sans-Serif", style , 16);
		b.setFont(font);
		return b;
	}
	
	//For now it's totally useless and I failed ....
	public void allOnFront() {
		//this.getFrame().setExtendedState(JFrame.NORMAL);
		for (AbstractApp app : appMap.values()) {
			if (app != null) {
				//app.getFrame().setExtendedState(JFrame.NORMAL);
			}
		}
	}
	
	/**
	 * Set s as the path of the file corresponding to p. 
	 * @param p != null
	 * @param s != null
	 */
	public void setFileMapPath(BCBEnum.Param p, String s) {
		if (p == null || s == null) {
			throw new IllegalArgumentException("Param or String is null");
		}
		if (this.pathsMap.containsKey(p)) {
			this.pathsMap.put(p, s);
		}
	}
	
	/**
	 * Add a browser in broMap to save its value after shutdown if the option 
	 * 	is checked.
	 * @param bro != null
	 */
	public void addBro(BCBEnum.Param p, Browser bro) {
		if (bro == null) {
			throw new IllegalArgumentException("The browser is null");
		}
		this.broMap.put(p, bro);
	}
	
	/**
	 * Add the location of a frame to the posMap
	 */
	public void addLoc(BCBEnum.Index i, Point p) {
		posMap.put(i, p);
	}
	
	public void updateReset() {
		getSettings().updateResetControllers();
	}
	
	/**
     * Return the app called index.name().
     * Note : If you want to call a specific method from a specific 
     * instance of AbstractApp class do this : 
     * //Be careful to make the right cast
     * Tractotron tra = (Tractotron) getApp(BCBEnum.Index.TRACTOTRON);
     * 
     * if (tra != null) {
     * 	//for example
     * 	System.out.println(tra.getDefaultLesions());
     * }
     * @param index : BCBEnum.Index corresponding to the app requested
     * @return   null if callApp(index) wasn't used
     * 		   instance of corresponding app 
     */
	
	public AbstractApp getApp(BCBEnum.Index index) {
		Tractotron tra = (Tractotron) getApp(BCBEnum.Index.TRACTOTRON);
	     if (tra != null) {
	      	//for example
	      	System.out.println(tra.getDefaultLesions());
	     }
		return appMap.get(index);
	}
	
	/**
	 * Old function to format buttons of the main panel
	 * @param but
	 */
	@SuppressWarnings("unused")
	private void formatButton(JButton but) {
		but.setIconTextGap(10);
		but.setVerticalTextPosition(SwingConstants.BOTTOM);
		but.setHorizontalTextPosition(SwingConstants.CENTER);
	}
	
	/**
	 * old function to format icons of buttons 
	 * @param path
	 * @param w
	 * @param h
	 * @return
	 */
	@SuppressWarnings("unused")
	private Icon buttonIcon(String path, int w, int h) {
		URL url = getClass().getClassLoader().getResource(path);
		ImageIcon icon = new ImageIcon(url);
		Image img = Tools.getScaledImage(icon.getImage(), w, h);
		icon.setImage(img);
		return icon;
	}
	
	// CALL FUNCTIONS which will call different functions in different frame
	
	/**
	 * Instanciate the AbstractApp called by index or make it visible
	 * if it is already instanciate.
	 * @param index : BCBEnum.Index designates the module
	 * @return
	 *    	getApp(index) != null
	 */
	public void callApp(BCBEnum.Index index) {
		AbstractApp app = appMap.get(index);
		if (app == null) {
			switch (index) {
				case TRACTOTRON : 
					app = new Tractotron(getWD(), getBCB());
					break;
				case ANACOM:
					app = new Anacom(getWD(), getBCB());
					break;
				case CORTICAL:
					app = new Cortical(getWD(), getBCB());
					break;
				case DISCONNECTOME:
					app = new Disco(getWD(), getBCB());
					break;
				case GENERAL:
					throw new IllegalStateException("There isn't GENERAL app");
				case NORMALISATION:
					app = new Normalisation(getWD(), getBCB());
					break;
				case FUNCON:
					app = new Funcon(getWD(), getBCB());
					break;
				case STATISTICAL:
					app = new Statistical(getWD(), getBCB());
					break;
				default:
					break;
			}
			appMap.put(index, app);
		} else {
			appMap.get(index).getFrame().setVisible(true);
		}
	}
	
	/**
	 * Call this to do general actions when sub-app is closed
	 */
	public void closingApp() {
		//activateButtons();
		saveDefPaths();
	}
	
	private void saveDefPaths() {
		if (savePaths) {
			for (Browser b : broMap.values()) {
				b.setConf();
			}
		} else {
			for (BCBEnum.Param p : pathsMap.keySet()) {
				getConfig().setVal(p, "");
			}
		}
	}

	public void closing() {		
		saveDefPaths();
		
		for (AbstractApp app : appMap.values()) {
			if (app != null && app.getFrame().isVisible()) {
				app.closing();
			}
		}
		//Must be before shutdown because we need frames ...
		if (setFrame.saveLocations()) {
			this.saveLocations();
		} else {
			for (BCBEnum.Index p : BCBEnum.Index.values()) {
				conf.deleteProp(p.name());
			}
		}
		
		for (AbstractApp app : appMap.values()) {
			if (app != null) {
				app.shutDown();
			}
		}
		conf.saveConfig();
		frame.dispose();
	}
	
	public void deactivateButtons(JButton but) {
		for (JButton j : butSet) {
			if (j != but) {
				j.setEnabled(false);
			}
		}
		// Update reset buttons of the SettingsFrame
		updateReset();
	}
	
	public void activateButtons() {
		for (JButton j : butSet) {
				j.setEnabled(true);
		}
	}

	public void savePaths(boolean b) {
		this.savePaths = b;
	}
	
	private void saveLocations() {
		this.addLoc(BCBEnum.Index.GENERAL, this.getLocation());
		for (BCBEnum.Index i : posMap.keySet()) {
			Point p = posMap.get(i);
			conf.setVal(i, (int)p.getX() + " " + (int)p.getY());
		}
	}
	
	public Point getLocation() {
		return frame.getLocationOnScreen();
	}
	
	public void setCustomLocation(JFrame f, BCBEnum.Index index) {
		String x = conf.getVal(index.name()).split(" ")[0];
		String y = conf.getVal(index.name()).split(" ")[1];
		f.setLocation(new Point(Integer.parseInt(x), Integer.parseInt(y)));
	}
	
	/**
	 * Remove the border of the component c
	 * @param c
	 */
	public void removeBorder(JComponent c) {
		c.setBorder(BorderFactory.createEmptyBorder());
	}

	//Model
	@Override
	public void openSettings() {
		setFrame.openSettings(BCBEnum.Index.GENERAL);
	}
	
	public void openSettings(BCBEnum.Index index) {
		setFrame.openSettings(index);
	}

	@Override
	public SettingsFrame getSettings() {
		return this.setFrame;
	}

	@Override
	public Config getConfig() {
		return this.conf;
	}
	
	//POINT D'ENTREE
	public static void main(final String[] args) {
		try {
			// Set cross-platform Java L&F (also called "Metal")
			UIManager.setLookAndFeel(
					UIManager.getCrossPlatformLookAndFeelClassName());
		} 
		catch (UnsupportedLookAndFeelException e) {
			// handle exception
		}
		catch (ClassNotFoundException e) {
			// handle exception
		}
		catch (InstantiationException e) {
			// handle exception
		}
		catch (IllegalAccessException e) {
			// handle exception
		}
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				//To increase the display time of tooltips
				javax.swing.ToolTipManager.sharedInstance().setDismissDelay(15000);
				if (args.length != 1) {
					String script = "";
					if (Tools.isOSX()) {
						script = "BCBToolKit.command";
					} else {
						script = "BCBToolKit.sh";
					}
		            System.out.println("You have to launch this application with " + script);
		        } else {
		        	new BCBToolKitIHM(args[0]).display();
		        }
			}
		});
	}
}

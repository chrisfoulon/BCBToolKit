package IHM;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.FocusEvent;
import java.awt.event.FocusListener;
import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.util.ArrayList;

import javax.swing.Icon;
import javax.swing.ImageIcon;
import javax.swing.JButton;
import javax.swing.JFileChooser;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.JTextField;

import Config.BCBEnum.Param;
import Config.BCBEnum.fType;
import Config.Config;


public class Browser extends JPanel {
	/**
	 * La variable path doit toujours être la même dans le browser que dans le Jtextfield.
	 */
	private static final long serialVersionUID = -1491377384697234931L;
	private static final int DEF_WIDTH = 310;
	//private static final int DEF_HEIGHT = 40;
	private static final int LINE_HEIGHT = 20;
	private static final int BUT_WID = 50;
	private JFrame frame;
	// The BCBToolBox which will be updated when path will changes.
	private BCBToolKitIHM bcb;
	private JButton but;
	private JLabel lbl;
	private JTextField fld;
	// Variable contenant le chemin actuellement sélectionné par le browser.
	private String path;
	// Variable contenant le fichier ayant pour chemin path.
	private File file;
	private Config conf;
	private Param paramName;
	private ArrayList<fType> ftype;
	private String defPath;
	
	public Browser(JFrame f, String label, ArrayList<fType> t, BCBToolKitIHM b) {
		this(f, label, t, null, null, DEF_WIDTH, b);
	}
	
	public Browser(JFrame f, String label, ArrayList<fType> t, int w, BCBToolKitIHM b) {
		this(f, label, t, null, null, w, b);
	}
	
	public Browser(JFrame f, String label, ArrayList<fType> t, Config c, Param pn, BCBToolKitIHM b) {
		this(f, label, t, c, pn, DEF_WIDTH, b);
	}
	
	/**
	  * Create a browser to select File or Directory
	  * @pre 
	  * 	f != null && t != null && t.length > 0
	  * @param 	f the frame which will contains the browser
	  * 		label the string to put in the label, if label.equals(""), we don't
	  * 			creat the label.
	  *			t the type of file/directory that will be filtered
	  *			c the config manager
	  *			pn the config parameter to use for find or update config value
	  *			w the width of the browser
	  *			b the BCBToolBox which we will update when path will changes.
	  */
	public Browser(JFrame f, String label, ArrayList<fType> t, Config c, Param pn,
				int w, BCBToolKitIHM b) {
		super();
		if (f == null) {
			throw new IllegalArgumentException("The frame is null");
		}
		if (t == null) {
			throw new IllegalArgumentException("The fType[] is null");
		}
		if (t.size() == 0) {
			throw new IllegalArgumentException("The fType[] doesn't contain element");
		}
		this.frame = f;
		this.ftype = t;
		this.conf = c;
		this.paramName = pn;
		this.path = "";
		this.file = null;
		this.defPath = "";
		
		createView(label, w);
		placeComponents();
		createControllers();
		this.setVisible(true);
	}
	
	private void createView(String label, int width) {
		if (!label.equals("")) {
			this.lbl = new JLabel(label, JLabel.CENTER);
		} else {
			this.lbl = null;
		}
		if (conf == null || conf.getVal(paramName).equals("")) {
			this.fld = new JTextField("");
		} else {
			this.fld = new JTextField("");
			String text = conf.getVal(paramName);
			File f = new File(text);
			if (extensionIntegrity(f)) {
				// If the path is valid, path, file and the field content will be upgraded
				setPath(text, f);
			}
		}
		URL url = getClass().getClassLoader().getResource("icon.png");
		Icon setIco = new ImageIcon(url); 
		int setIcoW = setIco.getIconWidth();
		this.but = new JButton(setIco);
		this.but.setToolTipText("Browse");
		//On fixe les dimensions : 
		this.fld.setPreferredSize(new Dimension(width - BUT_WID, LINE_HEIGHT));
		this.but.setPreferredSize(new Dimension(setIcoW + 4, setIcoW));
	}
	
	public boolean noLbl() {
		return (lbl == null);
	}
	
	public Param getParam() {
		return this.paramName;
	}
	
	public String getPath() {
		return this.path;
	}
	
	public File getFile() {
		return this.file;
	}
	
	public String getFldContent() {
		return this.fld.getText();
	}
	
	public String getDefPath() {
		return this.defPath;
	}
	
	private void placeComponents() {
		JPanel mainPanel = new JPanel(new GridLayout(2, 0, 0, 0)); {
			if (lbl != null) {
				JPanel p1 = new JPanel(new FlowLayout(FlowLayout.CENTER, 0, 0)); {
					p1.add(lbl);
				}
				mainPanel.add(lbl);
			}
			JPanel q = new JPanel(new FlowLayout(FlowLayout.CENTER, 5, 0)); {
				q.add(fld);
				q.add(but);
			}
			mainPanel.add(q);
		}
		this.add(mainPanel);
	}
	
	private void createControllers() {
		but.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				JFileChooser jfc;
				if (conf == null || conf.getVal(Param.STARTDIR).equals("")) {
					jfc = new JFileChooser(System.getProperty("user.home"));
				} else {
					jfc = new JFileChooser(conf.getVal(Param.STARTDIR));
				}
				jfcFType(jfc);
				File f = null;
				if (jfc.showSaveDialog(frame) == JFileChooser.APPROVE_OPTION) {
					f = jfc.getSelectedFile();
					if (!f.exists()) {
						try 
						{ 
							f.createNewFile();
						} 
						catch (IOException exception) 
						{ 
							showErrorMessage("The file can't be create \n"
									+ "(it can be a permission issue)"); 
							return;
						}
					}
					if (extensionIntegrity(f)) {
						String str = f.getAbsolutePath();
						fld.setText(str);
						setPath(str, f);
					} else {
						setOldFld();
					}
				}
            }
		});
		
		fld.addFocusListener(new FocusListener() {

		    @Override
		    public void focusLost(FocusEvent e) {
		    	String text = getFldContent().trim();
		    	if (!text.equals("")) {
		    		File f = new File(text);
		    		if (extensionIntegrity(f)) {
		    			setPath(text, f);
		    		} else {
		    			setOldFld();
		    		}
		    	} else {
		    		setPath("", null);
		    	}
		    }

		    @Override
		    public void focusGained(FocusEvent e) {
		    }
		});

		/*
		 * Detect the enter pressed event but when the popup appear, it 
		 * induce the focusLost event so focusLost event will be enough
		 * fld.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				String text = getFldContent();
				if (!text.equals("")) {
		    		File f = new File(text);
		    		if (extensionIntegrity(f)) {
		    			setPath(text, f);
		    		} else {
		    			setOldFld();
		    		}
		    	}
            }
		});*/
	}
	
	public void deactivate() {
		this.fld.setEnabled(false);
		this.fld.setEditable(false);
		this.but.setEnabled(false);
	}
	
	public void activate() {
		this.fld.setEnabled(true);
		this.fld.setEditable(true);
		this.but.setEnabled(true);
	}
	
	// Setters 
	/**
	 * Update the browser's path, the file attached and the content of the text field 
	 * if it is different or path.
	 * @param 	p a String which will be the current path
	 * 			f a File which will be the current file
	 */
	public void setPath(String p, File f) {
		this.path = p;
		this.file = f;
		if (!getFldContent().equals(p)) {
			this.fld.setText(path);
		}
		if (paramName != null && bcb != null) {
			bcb.setFileMapPath(paramName, p);
		}
	}
	
	private void setOldFld() {
		this.fld.setText(getPath());
	}
	
	/**
	 * Set the default path of the browser
	 * @param p the new default path
	 */
	public void setDefPath(String p) {
		File f = new File(p);
		if (extensionIntegrity(f)) {
			this.defPath = p;
		} else {
			showErrorMessage("The default path is invalid (" + paramName.name() + ") " + 
					p); 
		}
	}
	
	/**
	 * Reset the browser's path (and file) to its default.
	 * The integrity of the default path is insured when it is set.
	 */
	public void resetPath() {
		if (getDefPath().equals("")) {
			throw new IllegalStateException("The default path isn't define");
		}
		File f = new File(getDefPath());
		setPath(getDefPath(), f);
	}
	
	/**
	 * Use this function after you difined the default path to reset the path
	 * of the browser ONLY if conf.getVal(paramName).equals("")
	 */
	public void firstReset() {
		if (conf == null || conf.getVal(paramName).equals("")) {
			resetPath();
		}
	}
	
	/**
	 * Save the path in the conf propertie corresponding to paramName
	 */
	public void setConf() {
		if (paramName != null) {
			conf.setVal(paramName, getPath());
		}
	}
	
	// Outils	
	/**
	 * Give the file/directory type expected by the JFileChooser
	 * @param : jfc the JFileChooser
	 */
	 private void jfcFType(JFileChooser jfc) {
		 if (ftype.contains(fType.OTH)) {
			 //No constraints on the fileChooser.
			 //You have to manage the file type outside of this browser.
		 } else if (!ftype.contains(fType.DIR)) {
			 String[] extensions = new String[ftype.size()];
			 for (int i = 0; i < extensions.length; i++) {
				 extensions[i] = ftype.get(i).key();
			 }
			 String ext = "";
			 for (fType t : this.ftype) {
				 ext = ext + t.key();
			 }
			 /*
			  * TODO Add fileFilter to unable displaying files without the good extension. 
			  */
			 //FileNameExtensionFilter filter = new FileNameExtensionFilter(ext, extensions);                                
			 //jfc.addChoosableFileFilter(filter);
			 //jfc.setFileFilter(filter);
			 jfc.setFileSelectionMode(JFileChooser.FILES_ONLY);
		 } else {
			 jfc.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
		 }
	 }
	 
	 /**
	  * Vérifie que le type de fichier/dossier f récupéré dans le JFileChooser est le même que le mode 
	  * du browser et que le fichier/dossier f existe et est lisible.
	  * Cette fonction est appelée à chaque fois que l'on touche au textfield ou au filechooser, 
	  * donc avant de vérifier l'intégrité du chemin de fichier choisis, on va d'abord sauvegarder
	  *  le précédent contenu du textfield pour pouvoir revenir à l'état précédant 
	  *  qui était fonctionnel.
	  * 
	  */
	 private boolean extensionIntegrity(File f) {
		 if (ftype.contains(fType.DIR)) {
			 if (!f.isDirectory()) {
				 showErrorMessage("[" + f.getAbsolutePath() + "]" + " is not a directory");
				 return false;
			 }
		 } else {
			 boolean bool = false;
			 //We load a string with all accepted types to display it in case of error.
			 String err = "";
			 for (fType t : ftype) {
				 err = err + t.key() + " or ";
				 if (t.key().equalsIgnoreCase(Tools.getFileExtension(f.getName()))) {
					 bool = true;
				 } else if (t.key().equalsIgnoreCase(Tools.getArchiveExtension(f.getName()))) {
					 bool = true;
				 }
			 }
			 // If bool is false the type of the file isn't in ftype
			 if (!bool) {
				 showErrorMessage("This file type of " + f.getAbsolutePath() + 
						 " is not accepted, please use : " + err + "file extensions");
				 return false;
			 }
			 if (!f.canRead() || !f.isFile()) {
				 showErrorMessage("The file/folder can't be read (" + paramName.key() + ") " +
						 f.getAbsolutePath());
				 return false;
			 }
		 }
		 return true;
	 }
		 
	 public void showErrorMessage(String message) {
		 JTextArea area = new JTextArea(message);
		 area.setLineWrap(true);
		 JScrollPane scroller = new JScrollPane(area);
		 scroller.setPreferredSize(new Dimension(400, 200));
		 JOptionPane.showMessageDialog(
				 frame,
				 scroller,
				 "Error !",
				 JOptionPane.ERROR_MESSAGE
				 );
	 }
}

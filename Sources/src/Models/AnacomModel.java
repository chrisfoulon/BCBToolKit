package Models;

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.util.HashMap;
import java.util.Map;
import java.util.Scanner;

import javax.swing.JFrame;

import Config.BCBEnum;
import IHM.LoadingBar;
import IHM.Tools;

public class AnacomModel extends AbstractModel {
	public static final String logFile = "logAnacom.txt";
	private String csvFile;
	private String lesDir;
	private String resDir;
	//Threshold value
	private String thresh;
	//Control scores, it can be the mean score as a String or a path
	private String controls;
	//The name of the statistical test
	private String test;
	//Should we save tempory files ? 
	private String saveTmp;
	//Have we found zero inside data ? 
	private String detZero;
	// Which comparison we will use
	private String mode;
	//The minimum of voxels number per cluster
	private String nbVox = "0";
	private LoadingBar loading;
	
	private Map<String, String> test_map;
	private Map<String, String> mode_map;

	public AnacomModel(String path, JFrame f) {
		super(path, f, BCBEnum.Script.ANACOM.endPath());
		mode_map = new HashMap<String, String>();
		mode_map.put("No post-hoc test", "1");
		mode_map.put("Disconnected versus spared", "2");
		mode_map.put("Disconnected versus controls", "3");
		mode_map.put("Spared versus controls", "4");
		test_map = new HashMap<String, String>();
		test_map.put("Kruskal-Wallis", "1");
		test_map.put("Mann-Whitney", "2");
		test_map.put("t-test", "3");
		test_map.put("Kolmogorov-Smirnov", "4");
	}
	
	public void setCSV(String str) {
		csvFile = str;
	}

	public void setLesionDir(String str) {
		lesDir = str;
	}

	public void setResultDir(String str) {
		resDir = str;
	}
	
	public void setThreshold(String str) {
		thresh = str;
	}
	
	public void setControls(String str) {
		controls = str;
	}
	
	public void setTest(String str) {
		System.out.println(str);
		test = test_map.get(str);
	}
	
	public void setMode(String str) {
		mode = mode_map.get(str);
	}

	public void setSaveTmp(String str) {
		if (str == null || str.equals("") || (!str.equals("false") && !str.equals("true"))) {
			throw new IllegalArgumentException("The value of saveTmp must be \"true\" or \"false\"");
		}
		saveTmp = str;
	}
	
	public void setDetZero(String str) {
		if (str == null || str.equals("") || (!str.equals("false") && !str.equals("true"))) {
			throw new IllegalArgumentException("The value of saveTmp must be \"true\" or \"false\"");
		}
		detZero = str;
	}
	
	public void setNbVox(String str) {
		nbVox = str;
	}

	public void setLoadingBar(LoadingBar load) {
		loading = load;
	}

	public void setNbTicks(int nb) {
		loading.setNbTicks(nb);
	}
	
	/**
	 * Execute the script anacom.sh after checking it is executable by 
	 * the user.
	 */
	public void run() {
		String erreur = "";
		try {

			String[] array = {this.script,
					csvFile, lesDir, resDir, thresh, controls, test, saveTmp, detZero, nbVox, mode};
			int i = 0;
			for (String s : array) {
				System.out.println(i + " : " + s);
				i++;
			}


			proc = Runtime.getRuntime().exec(array, null, new File(this.path));

			Scanner out = new Scanner(proc.getInputStream());
			int progress = 0;
			setNbTicks(5);
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
				if (inLoop.startsWith("#")) {
					progress++;
					loading.setWidth(progress);					
				} else {
					System.out.println(inLoop);
				}
			}
			out.close();
			
			erreur = Tools.parseLog(resDir + "/" + logFile);
			
        } catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			Tools.showErrorMessage(frame, s);
			return;
		}
		if (proc != null) {
			Tools.classicErrorHandling(frame, erreur, "Data properly written in " + resDir);
			return;
		}
	}
}

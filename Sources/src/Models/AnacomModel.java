package Models;

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.attribute.PosixFilePermission;
import java.util.HashSet;
import java.util.Scanner;
import java.util.Set;

import javax.swing.JFrame;

import Config.BCBEnum;
import IHM.LoadingBar;
import IHM.Tools;

public class AnacomModel {
	public static final String logFile = "logAnacom.txt"; 
	private String csvFile;
	private String lesDir;
	private String resDir;
	//The execution path of the software
	private String path;
	//The folder of the script
	private String exeDir;
	//Threshold value
	private String thresh;
	//Control scores, it can be the mean score as a String or a path
	private String controls;
	//The name of the statistical test
	private String test;
	//Should we save tempory files ? 
	private String saveTmp;
	private LoadingBar loading;
	private JFrame frame;

	public AnacomModel(String path, JFrame f) {
		this.path = path;

		this.exeDir = path + "/Tools/scripts";
		this.frame = f;
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
		test = str;
	}

	public void setSaveTmp(String str) {
		if (str == null || str.equals("") || (!str.equals("false") && !str.equals("true"))) {
			throw new IllegalArgumentException("The value of saveTmp must be \"true\" or \"false\"");
		}
		saveTmp = str;
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
		//On donne les droits d'exécution sur le script
		Set<PosixFilePermission> perms = new HashSet<PosixFilePermission>();
		// add owners permissions
		perms.add(PosixFilePermission.OWNER_READ);
		perms.add(PosixFilePermission.OWNER_WRITE);
		perms.add(PosixFilePermission.OWNER_EXECUTE);
		// add group permissions
		perms.add(PosixFilePermission.GROUP_READ);
		perms.add(PosixFilePermission.GROUP_EXECUTE);
		// add others permissions
		perms.add(PosixFilePermission.OTHERS_READ);
		perms.add(PosixFilePermission.OTHERS_EXECUTE);

		String erreur = "";
		try {

			Files.setPosixFilePermissions(Paths.get(exeDir + BCBEnum.Script.ANACOM.endPath()), perms);

			String[] array = {exeDir + BCBEnum.Script.ANACOM.endPath(),
					csvFile, lesDir, resDir, thresh, controls, test, saveTmp};

			Process proc = Runtime.getRuntime().exec(array, null, new File(this.path));

			Scanner out = new Scanner(proc.getInputStream());
			int progress = 0;
			setNbTicks(5);
					
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
				if (inLoop.startsWith("#")) {
					progress++;
					loading.setWidth(progress);					
				}
			}
			out.close();
			//We erase the content of the log file if it exists
			PrintWriter eraser = new PrintWriter(resDir + "/" + logFile);
			eraser.print("");
			eraser.close();

			Scanner err = new Scanner(proc.getErrorStream());
			while (err.hasNextLine()) {
				String tmp = err.nextLine();
				erreur += tmp + "\n";
			}
			err.close();

		} catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			//System.out.println(s);
			Tools.showErrorMessage(frame, s);
			return;
		} catch (Throwable t) {
			t.printStackTrace();
		}

		if (erreur != "") {
			String message = "**** SCRIPT ERROR ****\n"
					+ erreur
					+ "**** SCRIPT ERROR END ****\n";
			Tools.showErrorMessage(frame, message);
			return;
		} else {
			Tools.showMessage(frame, "End !", "Finished!!! Results saved in " + resDir);
			return;
		}
	}
}

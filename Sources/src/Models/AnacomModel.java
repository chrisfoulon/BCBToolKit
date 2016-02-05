package Models;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileWriter;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStreamReader;
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
	private FilenameFilter fileNameFilter;

	public AnacomModel(String path, JFrame f) {
		this.path = path;

		this.exeDir = path + "/Tools/scripts";
		this.frame = f;

		// create new filename filter to recognize .nii and .nii.gz files
		this.fileNameFilter = new FilenameFilter() {
			@Override
			public boolean accept(File dir, String name) {
				if (name.endsWith(".nii") || name.endsWith(".nii.gz")) {
					return true;
				} else {
					return false;
				}
			}
		};
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
		
		System.out.println("????");

		try {

			Files.setPosixFilePermissions(Paths.get(exeDir + BCBEnum.Script.ANACOM.endPath()), perms);
			
			System.out.println(csvFile); 
			System.out.println(lesDir);
			System.out.println(resDir); 
			System.out.println(thresh);
			System.out.println(controls);
			System.out.println(test);
			System.out.println(saveTmp);

			String[] array = {exeDir + BCBEnum.Script.ANACOM.endPath(),
					csvFile, lesDir, resDir, thresh, controls, test, saveTmp};

			System.out.println("????");
			Process proc = Runtime.getRuntime().exec(array, null, new File(this.path));

			System.out.println("#######################Exec ok");
			//Scanner out = new Scanner(proc.getInputStream());
			InputStreamReader out = new InputStreamReader(proc.getInputStream());
			InputStreamReader err = new InputStreamReader(proc.getErrorStream());
			BufferedReader buff = new BufferedReader(out);
			String inLoop = null;
			int progress = 0;
			int count = 0;
			setNbTicks(new File(lesDir).listFiles(fileNameFilter).length);
			while ((inLoop = buff.readLine()) != null) {
				if (inLoop.startsWith("#")) {
					progress++;
					loading.setWidth(progress);					
				}
				System.out.println(inLoop);
				count++;
				System.out.println("~~~~~~~~COUNT :" + count);
			}
			out.close();
			//We erase the content of the log file if it exists
			PrintWriter eraser = new PrintWriter(resDir + "/" + logFile);
			eraser.print("");
			eraser.close();
			
			FileWriter writer = new FileWriter(resDir + "/" + logFile, true);
			System.out.println("#######################inputStream OK");

			String log = new String("");
			//InputStreamReader err = new InputStreamReader(proc.getErrorStream());
			BufferedReader br = new BufferedReader(err);
			String tmp = null;
			while ((tmp = br.readLine()) != null) {
				if (tmp.startsWith("+")) {
					log = tmp + "\n";
					System.out.println(tmp);
					try {
						writer.write(log);
					} catch (IOException e) {
						e.printStackTrace();
					}
				} else {
					erreur += tmp + "\n";
					System.out.println(erreur);
				}
			}
			writer.close();
			System.out.println("#######################Errorstream OK");
			err.close();
			
			System.out.println("#######################FileWriter OK");

		} catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			Tools.showErrorMessage(frame, s);
			return;
		} catch (Throwable t)
          {
            t.printStackTrace();
          }
		if (!erreur.equals("")) {
			String message = "**** SCRIPT ERROR ****\n"
					+ erreur
					+ "**** SCRIPT ERROR END ****\n";
			Tools.showErrorMessage(frame, message);
			return;
		} else {
			String finish = "Finished!!! Normalisation saved in " + resDir;
			String str2 = ""; 

			Tools.showMessage(frame, "End !", 
					"<html>" + finish + "<br />" + str2 + "</html>");
			return;
		}
	}
}

package Models;

import java.io.File;
import java.io.FilenameFilter;
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

import Config.BCBEnum.Script;
import IHM.LoadingBar;
import IHM.Tools;

public class CorticalModel {
	public static final String logFile = "logCorticalThickness.txt"; 
	private String t1Dir;
	private String resultDir;
	//The execution path of the software
	private String path;
	//The folder of the script
	private String exeDir;
	private LoadingBar loading;
	private FilenameFilter fileNameFilter;
	// The frame which will displays error and end messages 
	private JFrame frame;
	
	
	public CorticalModel(String path, JFrame f) {
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

	public void setT1Dir(String str) {
		t1Dir = str;
	}
	
	public void setResultDir(String str) {
		resultDir = str;
	}

	public void setLoadingBar(LoadingBar load) {
		loading = load;
	}
	
	public void setNbTicks(int nb) {
		loading.setNbTicks(nb);
	}

	public void run(Boolean saveTmp) {
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

		try {
			Files.setPosixFilePermissions(Paths.get(exeDir + Script.CORTICAL.endPath()), perms);
		} catch (IOException e) {
			e.printStackTrace();
		}

		String[] array = {exeDir + Script.CORTICAL.endPath(), t1Dir,
				resultDir, saveTmp.toString()};
		
		String erreur = "";
		
		try {
			Process proc = Runtime.getRuntime().exec(array, null, new File(this.path));

			Scanner out = new Scanner(proc.getInputStream());
			int progress = 0;
			setNbTicks(new File(t1Dir).listFiles(fileNameFilter).length);
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
				/*
				 * Attention la boucle augmente la barre de progression plusieurs fois par patient
				 * car le calcul est long et je voudrais bien que l'on voit quelques chose pendant les 
				 * calculs même pour un seul patient 
				 */
				if (inLoop.startsWith("#PATIENT#")) {
					progress++;
					loading.setWidth(progress);					
				}
				System.out.println(inLoop);
			}
			out.close();
			erreur = Tools.parseLog(resultDir + "/logThickness.txt");
		} catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			Tools.showErrorMessage(frame, s);
			return;
		}
		/*
		 * We have to handle manually the error stream because a function in the script 
		 * use the error file descriptor to write reports about the computation so we 
		 * will always have a non-empty error stream even without real error ...
		 */
		Tools.showLongMessage(frame, "Final Report", erreur);
	}
}

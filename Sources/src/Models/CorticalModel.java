package Models;

import java.io.File;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.util.Scanner;

import javax.swing.JFrame;

import Config.BCBEnum;
import IHM.LoadingBar;
import IHM.Tools;

public class CorticalModel extends AbstractModel {
	public static final String logFile = "logCorticalThickness.txt"; 
	private String t1Dir;
	private String resultDir;
	private LoadingBar loading;
	private FilenameFilter fileNameFilter;
	
	
	public CorticalModel(String path, JFrame f) {
		super(path, f, BCBEnum.Script.CORTICAL.endPath());

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
		String[] array = {script, t1Dir,
				resultDir, saveTmp.toString()};
		
		String erreur = "";
		
		try {
			proc = Runtime.getRuntime().exec(array, null, new File(this.path));

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
		if (proc != null) {
			/*
			 * We have to handle manually the error stream because a function in the script 
			 * use the error file descriptor to write reports about the computation so we 
			 * will always have a non-empty error stream even without real error ...
			 */
			Tools.showLongMessage(frame, "Final Report", erreur);
			return;
		}
	}
}

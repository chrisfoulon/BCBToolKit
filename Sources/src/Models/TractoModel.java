package Models;

import java.io.File;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.util.Scanner;
import java.util.StringTokenizer;

import javax.swing.JFrame;

import Config.BCBEnum;
import IHM.LoadingBar;
import IHM.Tools;

public class TractoModel extends AbstractModel {
	public static final String logFile = "logTractotron.txt"; 
	private String lesionDir;
	private String tractsDir;
	private String resultDir;
	private LoadingBar loading;
	private FilenameFilter fileNameFilter;

	public TractoModel(String path, JFrame f) {
		super(path, f, BCBEnum.Script.TRACTOTRON.endPath());
		
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

	public void setLesionDir(String str) {
		lesionDir = str;
	}

	public void setTractsDir(String str) {
		tractsDir = str;
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
	
	/**
	 * Execute the bash script TractotronParam.sh after verifying it is 
	 * executable by the user.
	 */
	public void run() {
		if (lesionDir == null) {
			throw new IllegalStateException(
					"You have to select the lesions directory");
		}
		if (tractsDir == null) {
			throw new IllegalStateException(
					"You have to select the tracts directory");
		}
		if (resultDir == null) {
			throw new IllegalStateException(
					"You have to select the result directory");
		}
				
		//Boolean error = false;
		String erreur = "";
		
		try {			
			String[] array = {script,
					lesionDir, tractsDir, resultDir};

			proc = Runtime.getRuntime().exec(array, null, new File(this.path));
			
			Scanner out = new Scanner(proc.getInputStream());
			String tmp = "";
			int progress = 0;
			while (out.hasNextLine()) {
				tmp = out.nextLine();
				if (tmp.startsWith("#")) {
					StringTokenizer token = new StringTokenizer(tmp, "#\n");
					if (token.hasMoreTokens()) {
						int tmpNumber = new File(tractsDir).listFiles(fileNameFilter).length;
						setNbTicks(tmpNumber + new File(lesionDir).listFiles(fileNameFilter).length
									* tmpNumber * 3);
					} else {
						progress++;
						loading.setWidth(progress);
					}
				} else {
					System.out.println(tmp);
				}
			}
			
			
			out.close();
			erreur = Tools.parseLog(resultDir + "/logTractotron.txt");
			
        } catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			Tools.showErrorMessage(frame, s);
			return;
		}
		if (proc != null) {
			Tools.classicErrorHandling(frame, erreur, "Data properly written in " + resultDir);
			return;
		}
	}	
}

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

public class FunconModel extends AbstractModel {
	public static final String logFile = "logResting.txt"; 
	private String T1Dir;
	private String RSDir;
	private String lesionDir;
	private String resultDir;
	private LoadingBar loading;
	private String sliceVal;
	//Should we save tempory files ? 
	private String saveTmp;
	private FilenameFilter fileNameFilter;
	
	public FunconModel(String path, JFrame f) {
		super(path, f, BCBEnum.Script.FUNCON.endPath());
		
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
		T1Dir = str;
	}
	
	public void setRSDir(String str) {
		RSDir = str;
	}
	
	public void setSliceTiming(String str) {
		sliceVal = str;
	}
	
	public void setLesionDir(String str) {
		lesionDir = str;
	}
	
	public void setResultDir(String str) {
		resultDir = str;
	}
	
	public void setSaveTmp(String str) {
		if (str == null || str.equals("") || (!str.equals("false") && !str.equals("true"))) {
			throw new IllegalArgumentException("The value of saveTmp must be true or false");
		}
		saveTmp = str;
	}

	public void setLoadingBar(LoadingBar load) {
		loading = load;
	}
	
	public void setNbTicks(int nb) {
		loading.setNbTicks(nb);
	}
	
	public String createSliceParameter() {
		if (sliceVal.equals("")) {
			throw new IllegalStateException(
					"Slice time correction have to be defined");
		}
		String str = "";
		if (sliceVal.equals("None")) {
			str = "0";
		} else if (sliceVal.equals("Regular up")) {
			str = "1";
		} else if (sliceVal.equals("Regular down")) {
			str = "2";
		} else if (sliceVal.equals("Interleaved")) {
			str = "5";
		}
		return str;
	}
	
	public void run() {
		if (T1Dir == null) {
			throw new IllegalStateException(
					"You have to select the T1 directory");
		}	
		if (RSDir == null) {
			throw new IllegalStateException(
					"You have to select the resting state directory");
		}
		if (resultDir == null) {
			throw new IllegalStateException(
					"You have to select the result directory");
		}
		String erreur = "";
		
		try {			
			String slice = createSliceParameter();
			String[] array = {script, T1Dir, RSDir, resultDir, slice, saveTmp, lesionDir};
			System.out.println(lesionDir);

			proc = Runtime.getRuntime().exec(array, null, new File(this.path));
			
			Scanner out = new Scanner(proc.getInputStream());
			int progress = 0;
			setNbTicks(new File(T1Dir).listFiles(fileNameFilter).length);
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
				if (inLoop.startsWith("#")) {
					progress++;
					loading.setWidth(progress);			
				}
			}
			out.close();
			erreur = Tools.parseLog(resultDir + "/" + logFile);
			
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

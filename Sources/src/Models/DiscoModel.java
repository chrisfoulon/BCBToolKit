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

public class DiscoModel extends AbstractModel {
	public static final String logFile = "logDisconnectome.txt"; 
	private String lesionDir;
	private String resultDir;
	private String extraFiles;
	private LoadingBar loading;
	private FilenameFilter fileNameFilter;
	private FilenameFilter trkFilter;
	
	public DiscoModel(String path, JFrame f) {
		super(path, f, BCBEnum.Script.DISCONNECTOME.endPath());
		this.extraFiles = path + "/Tools/extraFiles/Hypertron";
		
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
        // create new filename filter to recognize .trk files
        this.trkFilter = new FilenameFilter() {
           @Override
           public boolean accept(File dir, String name) {
        	  if (name.endsWith(".trk")) {
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
	
	public void setResultDir(String str) {
		resultDir = str;
	}

	public void setLoadingBar(LoadingBar load) {
		loading = load;
	}
	
	public void setNbTicks(int nb) {
		loading.setNbTicks(nb);
	}
	
	public void run() {
		if (lesionDir == null) {
			throw new IllegalStateException(
					"You have to select the lesions directory");
		}		
		String erreur = "";
		
		try {			
			String[] array = {script, lesionDir, resultDir};

			proc = Runtime.getRuntime().exec(array, null, new File(this.path));
			
			Scanner out = new Scanner(proc.getInputStream());
			int progress = 0;
			int nbTracks = new File(extraFiles).listFiles(trkFilter).length;
			setNbTicks(new File(lesionDir).listFiles(fileNameFilter).length * nbTracks);
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
				if (inLoop.startsWith("#")) {
					progress++;
					loading.setWidth(progress);					
				}
			}
			
			out.close();
			erreur = Tools.parseLog(resultDir + "/logDisconnectome.txt");
			
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

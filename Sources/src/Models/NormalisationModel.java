package Models;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
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

public class NormalisationModel extends AbstractModel {
	public static final String logFile = "logNormalisation.txt"; 
	private String tempFile;
	private String t1Dir;
	private String lesDir;
	private String resDir;
	//Other dir
	private String othDir;
	private String othRes;
	//The bet option value
	private String betOpt;
	//The SyN option value
	private String synOpt;
	//Should we save tempory files ? 
	private String saveTmp;
	private LoadingBar loading;
	private FilenameFilter fileNameFilter;
	
	public NormalisationModel(String path, JFrame f) {
		super(path, f, BCBEnum.Script.NORMALISATION.endPath());
		this.othDir = "";
		this.othRes = "";
		
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
	
	public void setTempFile(String str) {
		tempFile = str;
	}
	
	public void setLesionDir(String str) {
		lesDir = str;
	}
	
	public void setResultDir(String str) {
		resDir = str;
	}
	
	public void setOthDir(String str) {
		othDir = str;
	}
	
	public void setOthResDir(String str) {
		othRes = str;
	}
	
	public void setBetOpt(String str) {
		betOpt = str;
	}
	
	public void setSynOpt(String str) {
		synOpt = str;
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
	
	/*
	 * Fonction du bouton RUN si la checkBox hypertron est cochée. 
	 * On utilise un autre fichier de résultat car on a besoin d'un fichier texte et non
	 * d'un .xls. 
	 * On ne passait pas les chemins en paramètres donc on va rester cohérent avec le reste
	 * et utiliser les attributs. 
	 */
	public void run(boolean other) {
		
		String erreur = "";
		
		try {
			String[] array;
			
			String betOptFinal = "0.5";
			if (!betOpt.equals("")) {
				betOptFinal = betOpt;
			}
			
			if (other) {
				 array = new String[]{script, t1Dir,
						 lesDir, resDir, tempFile, betOptFinal, synOpt, saveTmp, othDir, othRes};
			} else {
				array = new String[]{script, t1Dir,
						 lesDir, resDir, tempFile, betOptFinal, synOpt, saveTmp};
			}

			proc = Runtime.getRuntime().exec(array, null, new File(this.path));
			
			Scanner out = new Scanner(proc.getInputStream());
			int progress = 0;
			setNbTicks(new File(t1Dir).listFiles(fileNameFilter).length);
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
				if (inLoop.startsWith("#")) {
					progress++;
					loading.setWidth(progress);					
				}
				System.out.println(inLoop);
			}
			out.close();
			//Error handling
			File source = new File(resDir + "/logNormalisation.txt");
			BufferedReader br = null;
			try {
				br = new BufferedReader(new FileReader(source));
			} catch (FileNotFoundException e1) {
				// TODO Auto-generated catch block
				e1.printStackTrace();
			}
			

			try {
				for(String line; (line = br.readLine()) != null; ) {
					String tmp = line.trim();
					String warn = "WARNING";
					String sigmas = "size of sigmas";
					if (tmp.toLowerCase().contains(warn.toLowerCase()) || 
							tmp.toLowerCase().contains(sigmas.toLowerCase()) ||
							tmp.equals("")) {
						//nothing !
					} else if (!line.startsWith("+")) {
						erreur += tmp + "\n";
					}
				}
			} catch (IOException e) {
				e.printStackTrace();
			} 
			try {
				br.close();
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}

		} catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			Tools.showErrorMessage(frame, s);
			return;
		}
		if (proc != null) {
			if (!erreur.equals("")) {
				String message = "**** SCRIPT ERROR ****\n"
						+ erreur
						+ "**** SCRIPT ERROR END ****\n";
				Tools.showErrorMessage(frame, message);
				return;
			} else {
				String finish = "Finished!!! Normalisation saved in " + resDir;
				String str2 = ""; 
				if (other) {
					str2 = "Other transformation saved in " + othRes;
				}

				Tools.showMessage(frame, "End !", 
						"<html>" + finish + "<br />" + str2 + "</html>");
				return;
			}
		}
	}
}

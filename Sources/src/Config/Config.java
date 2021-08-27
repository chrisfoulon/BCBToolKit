package Config;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.Properties;

public class Config {
	private File confFile;
	private Properties confTable;
	
	public Config(String path) {
		confFile = new File(path);
		if (confFile.exists() && (!confFile.canRead() || !confFile.canWrite())) {
			throw new IllegalArgumentException("Bad configuration file");
		} else if (!confFile.exists()) {
			try {
				confFile.createNewFile();
				confTable = new Properties();
				try {
					FileInputStream in = new FileInputStream(confFile);
					confTable.load(in);
					for (BCBEnum.Param p : BCBEnum.Param.values()) {
						confTable.setProperty(p.key(), "");
					}/* Vieux fichier de conf
					confTable.setProperty("default lesions", "");
					confTable.setProperty("default tracts", "");
					confTable.setProperty("default result", "");
					confTable.setProperty("start directory", "");*/
					in.close();
					saveConfig();
				} catch (FileNotFoundException e) {
					e.printStackTrace();
				} catch (IOException e) {
					e.printStackTrace();
				}
			} catch (IOException e) {
				e.printStackTrace();
			}
		} else {
			confTable = new Properties();
			try {
				FileInputStream in = new FileInputStream(confFile);
				confTable.load(in);
				in.close();
			} catch (FileNotFoundException e) {
				e.printStackTrace();
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
	}
	
	public String getVal(String prop) {
		return confTable.getProperty(prop, "");
	}
	
	public String getVal(BCBEnum.Param param) {
		return confTable.getProperty(param.key(), "");
	}
	
	public void setVal(BCBEnum.Param prop, String val) {
		confTable.setProperty(prop.key(), val);
	}
	
	public void setVal(BCBEnum.Index prop, String val) {
		confTable.setProperty(prop.name(), val);
	}
	
	public void deleteProp(BCBEnum.Param p) {
		confTable.remove(p);
	}
	
	public void deleteProp(String p) {
		confTable.remove(p);
	}
	
	public void saveConfig() {
		FileOutputStream out;
		try {
			out = new FileOutputStream(confFile);
			confTable.store(out, "---config---");
			out.close();
		} catch (IOException e) {
			System.err.println("Unable to write config file.");
		}
	}
}

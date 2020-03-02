package Settings;

import Config.Config;
import IHM.BCBToolKitIHM;

/**
 * @author Chris Foulon
 * Model the SettingsFrame which will manage settings of the BCBToolBox
 * 
 * @inv
 * 	
 * 
 * @cons
 * 	$DESC$ Receive a model(Config) c, the BCBToolBoxIHM bcb to be attached with
 * 		$ARGS$ Config c, BCBToolBoxIHM bcb
 * 		$PRE$ 
 * 			c != null && bcb != null
 * 	 	$POST$
 * 			
 */

public interface Settings {	
	//Getters Généraux
	Config getConf();
	BCBToolKitIHM getBCB();
	String getStartDir();
	
	//Setters Généraux
	/**
	 * 
	 * @pre 
	 * 	start != null
	 */
	void setStartDir(String start);
	
	/**
	 * Apply changes to the conf file
	 * 
	 * @post
	 * 	confFile stored the new settings
	 */
	void applyChanges();
}

package Config;

import java.util.ArrayList;

public final class BCBEnum {
	
	//R
	public static enum Index {
		GENERAL(0),
		TRACTOTRON(1),
		DISCONNECTOME(2),
		CORTICAL(3),
		NORMALISATION(4),
		STATISTICAL(5);
		
		private int index;
		
		private Index(int i) {
			this.index = i;
		}
		
		public int index() {
			return this.index;
		}
	}

	public static enum Param {
		/*
		 * WARNING : all string starting by "default" is use in 
		 * BCBToolBoxIHM to determine which file have to be saved in 
		 * the toolBox. 
		 * WARNING2 : Those String are parse to use the last part 
		 * as button name in the settingsFrame. (Each part is separated by 
		 * a space)
		 * WARNING3(The revenge) : The SECOND part of the String is used to 
		 * define a which application the field is belongs and must match 
		 * with a Index name() value !
		 */
		//Tractotron
		TLESDIR("default TRACTOTRON lesions"), 
		TTRADIR("default TRACTOTRON tracts"),
		TRESDIR("default TRACTOTRON result"),
		//Disconnectome maps
		DLESDIR("default DISCONNECTOME lesions"),
		DRESDIR("default DISCONNECTOME result"),
		//Cortical Thickness
		T1DIR("default CORTICAL T1"),
		CRESDIR("default CORTICAL result"),
		CSAVETMP("save CORTICAL tmpFiles"),
		//Normalization
		NTEMPDIR("default NORMALISATION template"),
		NT1DIR("default NORMALISATION T1"),
		NLESDIR("default NORMALISATION lesions"),
		NRESDIR("default NORMALISATION result"),
		NOTHDIR("default NORMALISATION other"),
		NOTHRESDIR("default NORMALISATION otherResult"),
		NBETOPT("brain extration threshold"),
		NSAVETMP("save NORMALISATION tmpFiles"),
		//Statistical analysis
		SMAP1DIR("default STATISTICAL map1"),
		SMAP2DIR("default STATISTICAL map2"),
		SRESDIR("default STATISTICAL result"),
		//General
		STARTDIR("start directory"),
		// WARNING : for SAVE_PATHS the value "" means false "true" means what it means
		SAVE_PATHS("save default paths");
		
		private String key = "";
		
		Param(String k) {
			this.key = k;
		}
		
		public String key() {
			return this.key;
		}
		
		public String toString(){
			return this.key();
		}
	}

	public static enum fType {
		DIR("dir"), 
		XLS("xls"),
		NII("nii"),
		NIIGZ("nii.gz"),
		OTH("oth");
		
		private String key = "";
		
		fType(String k) {
			this.key = k;
		}
		
		/**
		 * Return the file extension if the fType is a fileType
		 * @return String
		 */
		public String key() {
			return this.key;
		}
		
		public String toString(){
			return this.key();
		}
		
		public boolean isFileType() {
			return (this == NII || this == NIIGZ || this == XLS);
		}
		
		public ArrayList<fType> a() {
			 ArrayList<fType> arr =  new ArrayList<fType>();
			 arr.add(this);
			 return arr;
		}
	}

	private BCBEnum() {
		//Do nothing
	}
}

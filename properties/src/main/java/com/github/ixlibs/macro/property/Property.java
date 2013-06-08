/**
 * 
 */
package com.github.ixlibs.macro.property;
import java.lang.annotation.ElementType;
import java.lang.annotation.Target;

import org.eclipse.xtend.lib.macro.Active;

/**
 * @author zsombor
 *
 */
@Target(ElementType.FIELD)
@Active(PropertyProcessor.class)
public @interface Property {
	boolean read() default true;
	String readFunction() default "$";
	
	boolean write() default true;
	String writeFunction() default "$";
	boolean builder() default false;
}



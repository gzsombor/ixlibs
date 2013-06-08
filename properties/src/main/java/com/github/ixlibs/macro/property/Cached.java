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
@Active(CachedProcessor.class)
public @interface Cached {
	String invalidator() default "";
	boolean nullValid() default false;
	boolean threadsafe() default false;
}

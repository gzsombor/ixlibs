ixlibs
======

Collection of small libraries for Xtend

logging
==================

Simple active annotation for Xtend, which automaticly generate helper methods for logging 
for various frameworks. Currently it is possible to switch between using
 * java.util.logging
 * slf4j (logback)
 * plain log4j

Usage:

    @Logging(type="Slf4J")
    class Slf4jTest {
    	def method() {
    		info [|"hello world!"]
    		debug [|"logging "]		
    	}	
    }

or 

    @Logging(type="JavaUtilLogging")
    class JULTest {
        def method() {
            info [|"hello world!"]
            debug [|"logging "]		
        }	
    }

or

    @Logging(type="Log4J")
    class Log4jTest {
        def method() {
            info [|"hello world!"]
            debug [|"logging "]		
        }	
    }

where the info and debug methods take a lambda method, which only called, if the actual logging level is enabled.
Unfortunately, due for a bug, the 'type' in the annotation must be a string, and can't be an enumeration.

properties
==================

Improved version of the built-in @Property annotation :
 * generate setters which returns the current object, for chaining the calls
 * apply transformations on getters and setters, so only a copy is setted/getted.

Usage:

    class UserBean {
        // Readonly
        @Property(write=false, readFunction = "$ == null ? \"unknown\" : $.toUpperCase()" ) String name 

        // The returned list is an unmodifiable list
        @Property(readFunction="java.util.Collections.unmodifiableList($)") List<Role> roles

        // The date is copied, instead of referred 
        @Property(writeFunction="new java.util.Date($.getTime())") Date birth

        @Property(builder=true) String city
        @Property(builder=true) String zip
    }
will create:

    public String getName() {
      return _name == null ? "unknown" : _name.toUpperCase();
    }

    public List<String> getRoles() {
        return java.util.Collections.unmodifiableList(_roles);
    }
  
    public void setBirth(final Date value) {
        this. _birth = new java.util.Date(value.getTime());
    }
  
    public String getCity() {
        return _city;
    }
  
    public UserBean setCity(final String value) {
        this. _city = value;
        return this;
    }
  
    public String getZip() {
        return _zip;
    }
  
    public UserBean setZip(final String value) {
        this. _zip = value;
        return this;
    }


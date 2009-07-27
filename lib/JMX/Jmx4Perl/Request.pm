#!/usr/bin/perl

=head1 NAME

JMX::Jmx4Perl::Request - A jmx4perl request 

=head1 SYNOPSIS

  $req = JMX::Jmx4Perl::Request->new(READ,$mbean,$attribute);

=head1 DESCRIPTION

A L<JMX::Jmx4Perl::Request> encapsulates a request for various operational
types. Probably the most common type is C<READ> which let you
retrieve an attribute value from an MBeanServer. (In fact, at the time being,
this is the only one supported fo now)

The following attributes are available:

=over

=item mbean

Name of the targetted mbean in its canonical format. 

=item type

Type of request, which should be one of the constants 

=over

=item READ

Get the value of a attribute

=item WRITE

Write an attribute

=item EXEC

Execute an JMX operation 

=item REGISTER_NOTIFICATION

Register for a JMX notification (not supported yet)

=item REMOVE_NOTIFICATION

Remove a JMX notification (not supported yet)

=back

=item attribute

If type is C<READ> or C<WRITE> this specifies the requested
attribute

=item path

This optional parameter can be used to specify a nested value in an complex
mbean attribute or nested return value from a JMX operation. For example, the
MBean C<java.lang:type=Memory>'s attribute C<HeapMemoryUsage> is a complex
value, which looks in the JSON representation like

 "value":{"init":0,"max":518979584,"committed":41381888,"used":33442568}

So, to fetch the C<"used"> value only, specify C<used> as path within the
request. You can access deeper nested values by building up a path with "/" as
separator. This looks a bit like a simplified form of XPath.

=item max_depth, max_objects, max_list_size

With these objects you can restrict the size of the JSON structure
returned. C<max_depth> gives the maximum nesting level of the JSON
object,C<max_objects> returns the maximum number of objects to be returned in
total and C<max_list_size> restrict the number of all arrays and collections
(maps, lists) in the answer. Note, that you should use this restrictions if you
are doing massive bulk operations.

=back 

=head1 METHODS

=over 

=cut

package JMX::Jmx4Perl::Request;

use strict;
use vars qw(@ISA @EXPORT);
use Carp;
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = (
           "READ","WRITE","EXEC","LIST", "SEARCH",
           "REGNOTIF","REMNOTIF"
          );

use constant READ => "read";
use constant WRITE => "write";
use constant EXEC => "exec";
use constant LIST => "list";
use constant SEARCH => "search";
use constant REGNOTIF => "regnotif";
use constant REMNOTIF => "remnotif";

my $TYPES = 
{ map { $_ => 1 } (READ, WRITE, EXEC, LIST, SEARCH,
                   REGNOTIF, REMNOTIF) };

=item  $req = new JMX::Jmx4Perl::Request(....);

 $req = new JMX::Jmx4Perl::Request(READ,$mbean,$attribute,$path, { ... options ... } );
 $req = new JMX::Jmx4Perl::Request(READ,{ mbean => $mbean,... });
 $req = new JMX::Jmx4Perl::Request({type => READ, mbean => $mbean, ... });

The constructor can be used in various way. In the simplest form, you provide
the type as first argument and depending on the type one or more additional
attributes which specify the request. The second form uses the type as first
parameter and a hashref containing named parameter for the request parameters
(for the names, see above). Finally you can specify the arguments completely as
a hashref, using 'type' for the entry specifying the request type.

For the options C<max_depth>, C<max_objects> and C<max_list_size>, you can mix
them in into the hashref if using the hashed argument format. For the first
format, these options are given as a final hashref.

Note, depending on the type, some parameters are mandatory. The mandatory
parameters and the order of the arguments for the constructor variant without
named parameters are:

=over

=item C<READ>

 Order    : $mbean, $attribute, $path
 Mandatory: $mbean, $attribute

=item C<WRITE> 

 Order    : $mbean, $attribute, $value, $path
 Mandatory: $mbean, $attribute, $value

=item C<EXEC> 

 Order    : $mbean, $operation, $arg1, $arg2, ...
 Mandatory: $mbean, $operation


=item C<LIST>
  
 Order    : $path

=item C<SEARCH>

 Order    : $pattern
 Mandatory: $pattern

=back

=cut

sub new {
    my $class = shift;
    my $type = shift;
    my $self;

    # Hash as argument
    if (ref($type) eq "HASH") {
        $self = $type;
        $type = $self->{type};
    }
    croak "Invalid type '",$type,"' given (should be one of ",join(" ",keys %$TYPES),")" unless $TYPES->{$type};
    
    # Hash comes after type
    if (!$self) {
        if (ref($_[0]) eq "HASH") {
            $self = $_[0];
            $self->{type} = $type;
        } else {
            # Unnamed arguments
            $self = {type =>  $type};
            my $opts = $_[scalar(@_)-1];
            if (ref($opts) eq "HASH") {
                pop @_;
                map { $self->{$_} = $opts->{$_} } keys %$opts;
            } else {
            }
            if ($type eq READ) {
                $self->{mbean} = shift;
                $self->{attribute} = shift;
                $self->{path} = shift;
            } elsif ($type eq WRITE) {
                $self->{mbean} = shift;
                $self->{attribute} = shift;
                $self->{value} = shift;
                $self->{path} = shift;
            } elsif ($type eq EXEC) {
                $self->{mbean} = shift;
                $self->{operation} = shift;
                $self->{args} = [ @_ ];
            } elsif ($type eq LIST) {
                $self->{path} = shift;
            } elsif ($type eq SEARCH) {
                $self->{mbean} = shift;
            } else {
                croak "Type ",$type," not supported yet";
            }
        }
    }
    bless $self,(ref($class) || $class);
    $self->_validate();
    return $self;
}

=item $request->get("type")

Get a request parameter

=cut 

sub get {
    my $self = shift;
    my $name = shift;
    return $self->{$name};
}

# Internal check for validating that all arguments are given
sub _validate {
    my $self = shift;
    if ($self->{type} eq READ ||  $self->{type} eq WRITE) {
        die $self->{type} . ": No mbean name given\n",Dumper($self) unless $self->{mbean};
        die $self->{type} . ": No attribute name given\n" unless $self->{attribute};
    }
    if ($self->{type} eq WRITE) {
        die $self->{type} . ": No value given\n" unless $self->{value};
    }
    if ($self->{type} eq EXEC) {
        die $self->{type} . ": No mbean name given\n" unless $self->{mbean};
        die $self->{type} . ": No operation name given\n" unless $self->{operation};
    }
}

=back 

=head1 LICENSE

This file is part of jmx4perl.

Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

jmx4perl is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with jmx4perl.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 AUTHOR

roland@cpan.org

=cut

1;
